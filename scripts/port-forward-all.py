#!/usr/bin/env python3
import argparse
import json
import signal
import socket
import subprocess
import sys
import time
from pathlib import Path

import yaml


def load_yaml(path: Path) -> dict:
    if not path.exists():
        return {}
    with path.open("r", encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}
    return data if isinstance(data, dict) else {}


def run_kubectl_json(namespace: str, release: str, query_all: bool = False) -> dict:
    cmd = ["kubectl", "-n", namespace, "get", "svc"]
    if not query_all:
        cmd.extend(["-l", f"app.kubernetes.io/instance={release}"])
    cmd.extend(["-o", "json"])
    output = subprocess.check_output(cmd, text=True)
    return json.loads(output)


def service_has_ready_endpoints(namespace: str, service: str) -> bool:
    # Prefer EndpointSlice (stable API); fallback to Endpoints on older clusters.
    slice_cmd = [
        "kubectl",
        "-n",
        namespace,
        "get",
        "endpointslices.discovery.k8s.io",
        "-l",
        f"kubernetes.io/service-name={service}",
        "-o",
        "json",
    ]
    try:
        output = subprocess.check_output(slice_cmd, text=True, stderr=subprocess.DEVNULL)
        data = json.loads(output)
        for item in data.get("items", []):
            for endpoint in item.get("endpoints", []) or []:
                addresses = endpoint.get("addresses") or []
                conditions = endpoint.get("conditions") or {}
                # ready unset means "unknown", treat as ready-like to avoid false negatives.
                if addresses and conditions.get("ready", True) is not False:
                    return True
        return False
    except subprocess.CalledProcessError:
        pass

    endpoints_cmd = [
        "kubectl",
        "-n",
        namespace,
        "get",
        "endpoints",
        service,
        "-o",
        "json",
    ]
    try:
        output = subprocess.check_output(endpoints_cmd, text=True, stderr=subprocess.DEVNULL)
        data = json.loads(output)
    except subprocess.CalledProcessError:
        return False

    for subset in data.get("subsets", []) or []:
        if subset.get("addresses"):
            return True
    return False


def wait_for_service_endpoints(namespace: str, service: str, timeout_seconds: int) -> bool:
    deadline = time.time() + timeout_seconds
    while time.time() < deadline:
        if service_has_ready_endpoints(namespace, service):
            return True
        time.sleep(1)
    return False


def is_port_free(bind_address: str, port: int) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            sock.bind((bind_address, port))
        except OSError:
            return False
    return True


def choose_local_port(
    bind_address: str,
    remote_port: int,
    preferred_port: int | None,
    used_ports: set[int],
    next_port_ref: list[int],
) -> int:
    if preferred_port is not None:
        if preferred_port in used_ports:
            raise ValueError(f"preferred local port already in use by config: {preferred_port}")
        if not is_port_free(bind_address, preferred_port):
            raise ValueError(f"preferred local port is occupied on host: {preferred_port}")
        used_ports.add(preferred_port)
        return preferred_port

    if remote_port not in used_ports and is_port_free(bind_address, remote_port):
        used_ports.add(remote_port)
        return remote_port

    candidate = next_port_ref[0]
    while candidate in used_ports or not is_port_free(bind_address, candidate):
        candidate += 1
    next_port_ref[0] = candidate + 1
    used_ports.add(candidate)
    return candidate


def terminate_all(processes: list[dict]) -> None:
    for item in processes:
        proc: subprocess.Popen = item["proc"]
        if proc.poll() is None:
            proc.terminate()
    deadline = time.time() + 5
    while time.time() < deadline:
        if all(item["proc"].poll() is not None for item in processes):
            return
        time.sleep(0.2)
    for item in processes:
        proc: subprocess.Popen = item["proc"]
        if proc.poll() is None:
            proc.kill()


def main() -> int:
    script_root = Path(__file__).resolve().parents[1]
    default_config = script_root / "helm" / "dev-mode.yaml"

    parser = argparse.ArgumentParser(description="Port-forward all services in a Helm release")
    parser.add_argument("--config", default=str(default_config), help="dev-mode yaml path")
    parser.add_argument("--namespace", default="", help="k8s namespace override")
    parser.add_argument("--release", default="", help="helm release name override")
    parser.add_argument("--bind-address", default="", help="bind address override")
    parser.add_argument("--local-port-start", type=int, default=0, help="fallback local port start override")
    parser.add_argument(
        "--wait-ready-seconds",
        type=int,
        default=0,
        help="wait timeout for service endpoints before starting each forward",
    )
    parser.add_argument("--dry-run", action="store_true", help="print mapping without running")
    args = parser.parse_args()

    cfg = load_yaml(Path(args.config))
    dev_cfg = cfg.get("dev", {}) if isinstance(cfg.get("dev", {}), dict) else {}
    pf_cfg = dev_cfg.get("portForward", {}) if isinstance(dev_cfg.get("portForward", {}), dict) else {}

    namespace = args.namespace or dev_cfg.get("namespace") or "aigateway-system"
    release = args.release or dev_cfg.get("releaseName") or "aigateway"
    bind_address = args.bind_address or pf_cfg.get("bindAddress") or "127.0.0.1"
    local_port_start = args.local_port_start or int(pf_cfg.get("localPortStart") or 20000)
    wait_ready_seconds = args.wait_ready_seconds or int(pf_cfg.get("waitReadySeconds") or 180)

    skip_services = pf_cfg.get("skipServices") or []
    if not isinstance(skip_services, list):
        raise ValueError("dev.portForward.skipServices must be a list")
    skip_set = {str(item) for item in skip_services}

    include_services = pf_cfg.get("includeServices") or []
    if not isinstance(include_services, list):
        raise ValueError("dev.portForward.includeServices must be a list")
    include_set = {str(item) for item in include_services}

    service_ports_cfg = pf_cfg.get("servicePorts") or {}
    if not isinstance(service_ports_cfg, dict):
        raise ValueError("dev.portForward.servicePorts must be a map")

    try:
        svc_json = run_kubectl_json(namespace, release, query_all=bool(include_set))
    except subprocess.CalledProcessError as err:
        print(f"[ERROR] kubectl query failed: {err}", file=sys.stderr)
        return 1

    services = svc_json.get("items", [])
    if not services:
        print(f"[ERROR] no services found for release={release} in namespace={namespace}", file=sys.stderr)
        return 1

    mappings: list[dict] = []
    used_ports: set[int] = set()
    next_port_ref = [local_port_start]

    for svc in sorted(services, key=lambda item: item.get("metadata", {}).get("name", "")):
        name = svc.get("metadata", {}).get("name", "")
        if not name or name in skip_set:
            continue
        if include_set and name not in include_set:
            continue

        ports = svc.get("spec", {}).get("ports", []) or []
        if not ports:
            continue

        service_override = service_ports_cfg.get(name, {})
        if service_override is None:
            service_override = {}
        if not isinstance(service_override, dict):
            raise ValueError(f"dev.portForward.servicePorts.{name} must be a map")

        for port_obj in ports:
            remote_port = int(port_obj.get("port") or 0)
            if remote_port <= 0:
                continue

            preferred = None
            port_name = port_obj.get("name")
            if port_name and str(port_name) in service_override:
                preferred = int(service_override[str(port_name)])
            elif str(remote_port) in service_override:
                preferred = int(service_override[str(remote_port)])

            local_port = choose_local_port(
                bind_address=bind_address,
                remote_port=remote_port,
                preferred_port=preferred,
                used_ports=used_ports,
                next_port_ref=next_port_ref,
            )

            mappings.append(
                {
                    "service": name,
                    "remote_port": remote_port,
                    "local_port": local_port,
                }
            )

    if not mappings:
        print("[ERROR] no service ports selected for port-forward", file=sys.stderr)
        return 1

    print("[INFO] service port mapping:")
    for item in mappings:
        print(
            f"  - {item['service']}: {bind_address}:{item['local_port']} -> {item['remote_port']}"
        )

    if args.dry_run:
        return 0

    log_dir = script_root / ".logs" / "port-forward"
    log_dir.mkdir(parents=True, exist_ok=True)

    processes: list[dict] = []

    def handle_signal(signum, frame):  # type: ignore[no-untyped-def]
        _ = (signum, frame)
        terminate_all(processes)
        sys.exit(0)

    signal.signal(signal.SIGINT, handle_signal)
    signal.signal(signal.SIGTERM, handle_signal)

    ready_cache: dict[str, bool] = {}

    for item in mappings:
        service = item["service"]
        local_port = item["local_port"]
        remote_port = item["remote_port"]

        if service not in ready_cache:
            print(f"[INFO] waiting service ready endpoints: {service} (timeout={wait_ready_seconds}s)")
            ready_cache[service] = wait_for_service_endpoints(namespace, service, wait_ready_seconds)
            if not ready_cache[service]:
                print(
                    f"[WARN] service has no ready endpoints after timeout, skip: {service}",
                    file=sys.stderr,
                )
        if not ready_cache[service]:
            continue

        log_file = log_dir / f"{service}-{local_port}-{remote_port}.log"
        cmd = [
            "kubectl",
            "-n",
            namespace,
            "port-forward",
            f"svc/{service}",
            f"{local_port}:{remote_port}",
            "--address",
            bind_address,
        ]
        fh = log_file.open("a", encoding="utf-8")
        proc = subprocess.Popen(cmd, stdout=fh, stderr=subprocess.STDOUT)
        item["proc"] = proc
        item["fh"] = fh
        item["log_file"] = str(log_file)
        processes.append(item)

    if not processes:
        print("[ERROR] no running port-forward process started", file=sys.stderr)
        return 1

    print("[READY] port-forward started. Press Ctrl+C to stop all forwards.")

    try:
        while True:
            for item in processes:
                proc: subprocess.Popen = item["proc"]
                if proc.poll() is not None:
                    print(
                        f"[ERROR] port-forward exited: svc/{item['service']} "
                        f"{item['local_port']}:{item['remote_port']}, log={item['log_file']}",
                        file=sys.stderr,
                    )
                    terminate_all(processes)
                    return 1
            time.sleep(1)
    finally:
        for item in processes:
            fh = item.get("fh")
            if fh:
                fh.close()


if __name__ == "__main__":
    sys.exit(main())
