#!/usr/bin/env python3

import subprocess
import sys
from pathlib import Path

import yaml


REPO_ROOT = Path(__file__).resolve().parents[1]
CHART_DIR = REPO_ROOT / "higress" / "helm" / "higress"
DEV_VALUES = REPO_ROOT / "helm" / "dev-mode.yaml"
MINIKUBE_VALUES = CHART_DIR / "values-local-minikube.yaml"
K3D_VALUES = CHART_DIR / "values-production-k3d.yaml"
PROD_GRAY_VALUES = CHART_DIR / "values-production-gray.yaml"


PROFILE_FILES = {
    "dev": [DEV_VALUES],
    "minikube": [MINIKUBE_VALUES],
    "minikube-dev": [MINIKUBE_VALUES, DEV_VALUES],
    "k3d": [K3D_VALUES],
    "prod-gray": [PROD_GRAY_VALUES],
}


EXPECTED = {
    "dev": {
        "services": {
            "aigateway-console": ("ClusterIP", {8080}),
            "aigateway-portal": ("ClusterIP", {8081}),
            "aigateway-gateway": ("ClusterIP", {80, 443}),
        },
        "hostports": {
            "aigateway-gateway": {80, 443},
        },
    },
    "minikube": {
        "services": {
            "aigateway-console": ("LoadBalancer", {8080}),
            "aigateway-portal": ("LoadBalancer", {8081}),
            "aigateway-gateway": ("LoadBalancer", {80, 443}),
        },
        "hostports": {},
    },
    "minikube-dev": {
        "services": {
            "aigateway-console": ("ClusterIP", {8080}),
            "aigateway-portal": ("ClusterIP", {8081}),
            "aigateway-gateway": ("ClusterIP", {80, 443}),
        },
        "hostports": {
            "aigateway-gateway": {80, 443},
        },
    },
    "k3d": {
        "services": {
            "aigateway-console": ("LoadBalancer", {8080}),
            "aigateway-portal": ("LoadBalancer", {8081}),
            "aigateway-gateway": ("LoadBalancer", {80, 443}),
        },
        "hostports": {},
    },
    "prod-gray": {
        "services": {
            "aigateway-console": ("LoadBalancer", {8080}),
            "aigateway-portal": ("LoadBalancer", {8081}),
            "aigateway-gateway": ("LoadBalancer", {80, 443}),
        },
        "hostports": {},
    },
}


def render_chart(values_files: list[Path]) -> str:
    cmd = ["helm", "template", "aigateway", str(CHART_DIR)]
    for value_file in values_files:
        cmd.extend(["-f", str(value_file)])
    return subprocess.check_output(cmd, text=True, cwd=REPO_ROOT)


def parse_manifests(rendered: str) -> tuple[dict[str, tuple[str, set[int]]], dict[str, set[int]]]:
    services: dict[str, tuple[str, set[int]]] = {}
    hostports: dict[str, set[int]] = {}

    for doc in yaml.safe_load_all(rendered):
        if not isinstance(doc, dict):
            continue

        kind = doc.get("kind")
        metadata = doc.get("metadata") or {}
        name = metadata.get("name")
        if not name:
            continue

        if kind == "Service":
            spec = doc.get("spec") or {}
            service_type = spec.get("type", "ClusterIP")
            ports = {int(port.get("port")) for port in (spec.get("ports") or []) if port.get("port") is not None}
            services[name] = (service_type, ports)
            continue

        if kind == "Deployment":
            template_spec = (((doc.get("spec") or {}).get("template") or {}).get("spec") or {})
            for container in template_spec.get("containers") or []:
                for port in container.get("ports") or []:
                    host_port = port.get("hostPort")
                    if host_port is None:
                        continue
                    hostports.setdefault(name, set()).add(int(host_port))

    return services, hostports


def validate_profile(profile: str, values_files: list[Path]) -> list[str]:
    rendered = render_chart(values_files)
    services, hostports = parse_manifests(rendered)
    expected = EXPECTED[profile]
    errors: list[str] = []

    for service_name, (expected_type, expected_ports) in expected["services"].items():
        actual = services.get(service_name)
        if actual is None:
            errors.append(f"[{profile}] missing Service: {service_name}")
            continue

        actual_type, actual_ports = actual
        if actual_type != expected_type:
            errors.append(
                f"[{profile}] service {service_name} type mismatch: expected {expected_type}, got {actual_type}"
            )
        if actual_ports != expected_ports:
            errors.append(
                f"[{profile}] service {service_name} ports mismatch: expected {sorted(expected_ports)}, got {sorted(actual_ports)}"
            )

    tracked_hostports = {
        name: ports
        for name, ports in hostports.items()
        if name in {"aigateway-console", "aigateway-portal", "aigateway-gateway"}
    }
    if tracked_hostports != expected["hostports"]:
        errors.append(
            f"[{profile}] hostPort mismatch: expected {expected['hostports']}, got {tracked_hostports}"
        )

    return errors


def validate_dev_port_forward() -> list[str]:
    cfg = yaml.safe_load(DEV_VALUES.read_text(encoding="utf-8")) or {}
    dev_cfg = cfg.get("dev") or {}
    pf_cfg = dev_cfg.get("portForward") or {}
    errors: list[str] = []

    include_services = pf_cfg.get("includeServices") or []
    expected_services = [
        "aigateway-console",
        "aigateway-console-grafana",
        "aigateway-console-loki",
        "aigateway-console-prometheus",
        "aigateway-controller",
        "aigateway-plugin-server",
        "aigateway-portal",
        "mysql-server",
        "redis-stack-server",
    ]
    if include_services != expected_services:
        errors.append(
            "[dev-port-forward] includeServices mismatch: "
            f"expected {expected_services}, got {include_services}"
        )

    service_ports = pf_cfg.get("servicePorts") or {}
    expected_ports = {
        "aigateway-console": {"8080": 8080},
        "aigateway-console-grafana": {"3000": 3000},
        "aigateway-console-loki": {"3100": 3100, "7946": 7946, "9095": 9095},
        "aigateway-console-prometheus": {"9090": 9090},
        "aigateway-controller": {
            "443": 15443,
            "8888": 8888,
            "8889": 8889,
            "15010": 15010,
            "15012": 15012,
            "15014": 15014,
            "15051": 15051,
        },
        "aigateway-plugin-server": {"80": 18080},
        "aigateway-portal": {"8081": 8081},
        "mysql-server": {"3306": 3306},
        "redis-stack-server": {"6379": 6379},
    }
    if service_ports != expected_ports:
        errors.append(
            f"[dev-port-forward] servicePorts mismatch: expected {expected_ports}, got {service_ports}"
        )

    return errors


def main() -> int:
    all_errors: list[str] = []

    for profile, values_files in PROFILE_FILES.items():
        all_errors.extend(validate_profile(profile, values_files))

    all_errors.extend(validate_dev_port_forward())

    if all_errors:
        for error in all_errors:
            print(error, file=sys.stderr)
        return 1

    print("Helm exposure validation passed for dev, minikube, minikube-dev, k3d, and prod-gray.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
