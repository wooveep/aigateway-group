#!/usr/bin/env python3

from __future__ import annotations

import argparse
import http.client
import os
import re
import shlex
import socket
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from urllib.parse import urlparse

import yaml


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = REPO_ROOT / "helm" / "image-versions.yaml"
SAFE_UNQUOTED = re.compile(r"^[A-Za-z0-9._/-]+$")
YAML_KEY_LINE = re.compile(r"^(?P<indent>\s*)(?P<key>[^:#][^:]*?):(?P<tail>.*)$")
YAML_VALUE_LINE = re.compile(r"^(?P<space>\s*)(?P<value>[^#]*?)(?P<comment>\s+#.*)?$")
RESERVED_SCALARS = {"null", "true", "false", "yes", "no", "on", "off", "~"}
DEV_TAG_SUFFIX = re.compile(r"^(?P<base>.+?)(?:-dev-\d{14})?$")
MYSQL_DSN_TCP = re.compile(r"@tcp\((?P<target>[^)]+)\)")


@dataclass(frozen=True)
class ImageSpec:
    repository: str
    tag: str


@dataclass(frozen=True)
class Binding:
    file_path: str
    repository_path: tuple[str, ...]
    tag_path: tuple[str, ...]


@dataclass(frozen=True)
class Manifest:
    manifest_path: Path
    chart_dir: Path
    dev_config_file: Path
    local_values_file: Path
    namespace: str
    release_name: str
    build_components: list[str]
    minikube: dict[str, object]
    images: dict[str, ImageSpec]


@dataclass(frozen=True)
class PortForwardMapping:
    service: str
    remote_port: int
    local_port: int


@dataclass(frozen=True)
class CheckResult:
    name: str
    required: bool
    status: str
    detail: str


SYNC_BINDINGS: dict[str, list[Binding]] = {
    "aigateway": [
        Binding(
            "higress/helm/higress/values-production-gray.yaml",
            ("aigateway-console", "certmanager", "image", "repository"),
            ("aigateway-console", "certmanager", "image", "tag"),
        ),
        Binding(
            "higress/helm/higress/values-production-k3d.yaml",
            ("aigateway-console", "certmanager", "image", "repository"),
            ("aigateway-console", "certmanager", "image", "tag"),
        ),
        Binding(
            "aigateway-console/helm/values-production-gray.yaml",
            ("certmanager", "image", "repository"),
            ("certmanager", "image", "tag"),
        ),
    ],
    "controller": [
        Binding(
            "helm/dev-mode.yaml",
            ("higress-core", "controller", "repository"),
            ("higress-core", "controller", "tag"),
        ),
        Binding(
            "higress/helm/higress/values-local-minikube.yaml",
            ("higress-core", "controller", "repository"),
            ("higress-core", "controller", "tag"),
        ),
        Binding(
            "higress/helm/higress/values-production-k3d.yaml",
            ("higress-core", "controller", "repository"),
            ("higress-core", "controller", "tag"),
        ),
        Binding(
            "higress/helm/higress/values-production-gray.yaml",
            ("higress-core", "controller", "repository"),
            ("higress-core", "controller", "tag"),
        ),
        Binding(
            "higress/helm/core/values-production-gray.yaml",
            ("controller", "repository"),
            ("controller", "tag"),
        ),
    ],
    "gateway": [
        Binding(
            "helm/dev-mode.yaml",
            ("higress-core", "gateway", "repository"),
            ("higress-core", "gateway", "tag"),
        ),
        Binding(
            "higress/helm/higress/values-local-minikube.yaml",
            ("higress-core", "gateway", "repository"),
            ("higress-core", "gateway", "tag"),
        ),
        Binding(
            "higress/helm/higress/values-production-k3d.yaml",
            ("higress-core", "gateway", "repository"),
            ("higress-core", "gateway", "tag"),
        ),
        Binding(
            "higress/helm/higress/values-production-gray.yaml",
            ("higress-core", "gateway", "repository"),
            ("higress-core", "gateway", "tag"),
        ),
        Binding(
            "higress/helm/core/values-production-gray.yaml",
            ("gateway", "repository"),
            ("gateway", "tag"),
        ),
    ],
    "pilot": [
        Binding(
            "helm/dev-mode.yaml",
            ("higress-core", "pilot", "repository"),
            ("higress-core", "pilot", "tag"),
        ),
        Binding(
            "higress/helm/higress/values-local-minikube.yaml",
            ("higress-core", "pilot", "repository"),
            ("higress-core", "pilot", "tag"),
        ),
        Binding(
            "higress/helm/higress/values-production-k3d.yaml",
            ("higress-core", "pilot", "repository"),
            ("higress-core", "pilot", "tag"),
        ),
        Binding(
            "higress/helm/higress/values-production-gray.yaml",
            ("higress-core", "pilot", "repository"),
            ("higress-core", "pilot", "tag"),
        ),
        Binding(
            "higress/helm/core/values-production-gray.yaml",
            ("pilot", "repository"),
            ("pilot", "tag"),
        ),
    ],
    "plugin-server": [
        Binding(
            "helm/dev-mode.yaml",
            ("higress-core", "pluginServer", "repository"),
            ("higress-core", "pluginServer", "tag"),
        ),
        Binding(
            "higress/helm/higress/values-local-minikube.yaml",
            ("higress-core", "pluginServer", "repository"),
            ("higress-core", "pluginServer", "tag"),
        ),
        Binding(
            "higress/helm/higress/values-production-k3d.yaml",
            ("higress-core", "pluginServer", "repository"),
            ("higress-core", "pluginServer", "tag"),
        ),
        Binding(
            "higress/helm/higress/values-production-gray.yaml",
            ("higress-core", "pluginServer", "repository"),
            ("higress-core", "pluginServer", "tag"),
        ),
        Binding(
            "higress/helm/core/values-production-gray.yaml",
            ("pluginServer", "repository"),
            ("pluginServer", "tag"),
        ),
    ],
    "console": [
        Binding(
            "helm/dev-mode.yaml",
            ("aigateway-console", "image", "repository"),
            ("aigateway-console", "image", "tag"),
        ),
        Binding(
            "higress/helm/higress/values-local-minikube.yaml",
            ("aigateway-console", "image", "repository"),
            ("aigateway-console", "image", "tag"),
        ),
        Binding(
            "higress/helm/higress/values-production-k3d.yaml",
            ("aigateway-console", "image", "repository"),
            ("aigateway-console", "image", "tag"),
        ),
        Binding(
            "higress/helm/higress/values-production-gray.yaml",
            ("aigateway-console", "image", "repository"),
            ("aigateway-console", "image", "tag"),
        ),
        Binding(
            "aigateway-console/helm/values-production-gray.yaml",
            ("image", "repository"),
            ("image", "tag"),
        ),
    ],
    "portal": [
        Binding(
            "helm/dev-mode.yaml",
            ("aigateway-portal", "image", "repository"),
            ("aigateway-portal", "image", "tag"),
        ),
        Binding(
            "higress/helm/higress/values-local-minikube.yaml",
            ("aigateway-portal", "image", "repository"),
            ("aigateway-portal", "image", "tag"),
        ),
        Binding(
            "higress/helm/higress/values-production-k3d.yaml",
            ("aigateway-portal", "image", "repository"),
            ("aigateway-portal", "image", "tag"),
        ),
        Binding(
            "higress/helm/higress/values-production-gray.yaml",
            ("aigateway-portal", "image", "repository"),
            ("aigateway-portal", "image", "tag"),
        ),
        Binding(
            "aigateway-portal/helm/values.yaml",
            ("image", "repository"),
            ("image", "tag"),
        ),
        Binding(
            "aigateway-portal/helm/values.yaml",
            ("backend", "image", "repository"),
            ("backend", "image", "tag"),
        ),
    ],
}


def fail(message: str) -> int:
    print(f"[ERROR] {message}", file=sys.stderr)
    return 1


def yaml_load(path: Path) -> dict:
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    if not isinstance(data, dict):
        raise ValueError(f"{path} does not contain a YAML mapping at the top level")
    return data


def first_non_empty(*values: object) -> str:
    for value in values:
        text = str(value or "").strip()
        if text:
            return text
    return ""


def parse_bool(value: object, default: bool = False) -> bool:
    if isinstance(value, bool):
        return value
    if value is None:
        return default
    text = str(value).strip().lower()
    if not text:
        return default
    if text in {"1", "true", "yes", "on"}:
        return True
    if text in {"0", "false", "no", "off"}:
        return False
    return default


def normalize_components(value: object) -> list[str]:
    if isinstance(value, str):
        parts = [item.strip() for item in value.split(",")]
        return [item for item in parts if item]
    if isinstance(value, list):
        return [str(item).strip() for item in value if str(item).strip()]
    raise ValueError("buildComponents must be a list or comma-separated string")


def load_manifest(path: Path) -> Manifest:
    raw = yaml_load(path)
    defaults = raw.get("defaults") or {}
    minikube = raw.get("minikube") or {}
    images_raw = raw.get("images") or {}

    if not isinstance(defaults, dict):
        raise ValueError("defaults must be a mapping")
    if not isinstance(minikube, dict):
        raise ValueError("minikube must be a mapping")
    if not isinstance(images_raw, dict):
        raise ValueError("images must be a mapping")

    missing_images = sorted(set(SYNC_BINDINGS) - set(images_raw))
    if missing_images:
        raise ValueError(f"manifest is missing images: {', '.join(missing_images)}")

    images: dict[str, ImageSpec] = {}
    for name in SYNC_BINDINGS:
        item = images_raw.get(name)
        if not isinstance(item, dict):
            raise ValueError(f"images.{name} must be a mapping")
        repository = str(item.get("repository", "")).strip()
        tag = str(item.get("tag", "")).strip()
        if not repository or not tag:
            raise ValueError(f"images.{name} must include repository and tag")
        images[name] = ImageSpec(repository=repository, tag=tag)

    chart_dir = REPO_ROOT / str(defaults.get("chartDir", "higress/helm/higress"))
    dev_config_file = REPO_ROOT / str(defaults.get("devConfigFile", "helm/dev-mode.yaml"))
    local_values_file = REPO_ROOT / str(
        defaults.get("localValuesFile", "higress/helm/higress/values-local-minikube.yaml")
    )
    namespace = str(defaults.get("namespace", "aigateway-system")).strip()
    release_name = str(defaults.get("releaseName", "aigateway")).strip()
    build_components = normalize_components(defaults.get("buildComponents", []))

    if not chart_dir.is_dir():
        raise ValueError(f"chartDir does not exist: {chart_dir}")
    if not dev_config_file.is_file():
        raise ValueError(f"devConfigFile does not exist: {dev_config_file}")
    if not local_values_file.is_file():
        raise ValueError(f"localValuesFile does not exist: {local_values_file}")
    if not build_components:
        raise ValueError("defaults.buildComponents must not be empty")

    return Manifest(
        manifest_path=path,
        chart_dir=chart_dir,
        dev_config_file=dev_config_file,
        local_values_file=local_values_file,
        namespace=namespace,
        release_name=release_name,
        build_components=build_components,
        minikube=minikube,
        images=images,
    )


def load_dev_port_forward_config(path: Path) -> tuple[str, list[PortForwardMapping]]:
    cfg = yaml_load(path)
    dev_cfg = cfg.get("dev", {}) if isinstance(cfg.get("dev", {}), dict) else {}
    pf_cfg = dev_cfg.get("portForward", {}) if isinstance(dev_cfg.get("portForward", {}), dict) else {}
    bind_address = str(pf_cfg.get("bindAddress") or "127.0.0.1").strip() or "127.0.0.1"
    include_services = pf_cfg.get("includeServices") or []
    if not isinstance(include_services, list):
        raise ValueError("dev.portForward.includeServices must be a list")
    service_ports_cfg = pf_cfg.get("servicePorts") or {}
    if not isinstance(service_ports_cfg, dict):
        raise ValueError("dev.portForward.servicePorts must be a map")

    mappings: list[PortForwardMapping] = []
    for service in include_services:
        override = service_ports_cfg.get(str(service)) or {}
        if not isinstance(override, dict):
            raise ValueError(f"dev.portForward.servicePorts.{service} must be a map")
        for remote_port, local_port in override.items():
            mappings.append(
                PortForwardMapping(
                    service=str(service),
                    remote_port=int(remote_port),
                    local_port=int(local_port),
                )
            )
    mappings.sort(key=lambda item: (item.local_port, item.service, item.remote_port))
    return bind_address, mappings


def read_backend_client_config(path: Path) -> dict[str, object]:
    cfg = yaml_load(path)
    clients = cfg.get("clients", {}) if isinstance(cfg.get("clients", {}), dict) else {}

    k8s_cfg = clients.get("k8s", {}) if isinstance(clients.get("k8s", {}), dict) else {}
    portaldb_cfg = clients.get("portaldb", {}) if isinstance(clients.get("portaldb", {}), dict) else {}
    grafana_cfg = clients.get("grafana", {}) if isinstance(clients.get("grafana", {}), dict) else {}

    return {
        "k8s": {
            "enabled": parse_bool(os.environ.get("AIGATEWAY_CONSOLE_K8S_ENABLED"), k8s_cfg.get("enabled", False)),
            "namespace": first_non_empty(
                os.environ.get("AIGATEWAY_CONSOLE_K8S_NAMESPACE"),
                os.environ.get("HIGRESS_CONSOLE_CONTROLLER_WATCHED_NAMESPACE"),
                k8s_cfg.get("namespace"),
                "aigateway-system",
            ),
            "kubectl_bin": first_non_empty(
                os.environ.get("AIGATEWAY_CONSOLE_KUBECTL_BIN"),
                k8s_cfg.get("kubectlBin"),
                "kubectl",
            ),
            "kubeconfig": first_non_empty(
                os.environ.get("KUBECONFIG"),
                os.environ.get("AIGATEWAY_CONSOLE_KUBECONFIG"),
                k8s_cfg.get("kubeconfig"),
            ),
        },
        "portaldb": {
            "enabled": parse_bool(
                os.environ.get("AIGATEWAY_CONSOLE_PORTALDB_ENABLED"),
                portaldb_cfg.get("enabled", False),
            ),
            "driver": first_non_empty(
                os.environ.get("AIGATEWAY_CONSOLE_PORTALDB_DRIVER"),
                portaldb_cfg.get("driver"),
                "mysql",
            ),
            "dsn": first_non_empty(
                os.environ.get("AIGATEWAY_CONSOLE_PORTALDB_DSN"),
                os.environ.get("PORTAL_MYSQL_DSN"),
                portaldb_cfg.get("dsn"),
            ),
        },
        "grafana": {
            "enabled": parse_bool(
                os.environ.get("AIGATEWAY_CONSOLE_GRAFANA_ENABLED"),
                grafana_cfg.get("enabled", False),
            ),
            "base_url": first_non_empty(
                os.environ.get("AIGATEWAY_CONSOLE_GRAFANA_BASE_URL"),
                grafana_cfg.get("baseURL"),
                "http://127.0.0.1:3000",
            ),
        },
    }


def get_nested_value(data: dict, path: tuple[str, ...]) -> object:
    current: object = data
    for key in path:
        if not isinstance(current, dict) or key not in current:
            raise KeyError(".".join(path))
        current = current[key]
    return current


def dotted(path: tuple[str, ...]) -> str:
    return ".".join(path)


def count_indent(line: str) -> int:
    return len(line) - len(line.lstrip(" "))


def block_end(lines: list[str], index: int) -> int:
    parent_indent = count_indent(lines[index])
    for i in range(index + 1, len(lines)):
        stripped = lines[i].strip()
        if not stripped or stripped.startswith("#"):
            continue
        if count_indent(lines[i]) <= parent_indent:
            return i
    return len(lines)


def child_indent(lines: list[str], index: int) -> int:
    parent_indent = count_indent(lines[index])
    end = block_end(lines, index)
    for i in range(index + 1, end):
        stripped = lines[i].strip()
        if not stripped or stripped.startswith("#"):
            continue
        indent = count_indent(lines[i])
        if indent > parent_indent:
            return indent
    return parent_indent + 2


def find_key_line(lines: list[str], key: str, indent: int, start: int, end: int) -> int:
    for i in range(start, end):
        stripped = lines[i].strip()
        if not stripped or stripped.startswith("#"):
            continue
        match = YAML_KEY_LINE.match(lines[i])
        if not match:
            continue
        current_indent = len(match.group("indent"))
        if current_indent < indent:
            break
        if current_indent == indent and match.group("key").strip() == key:
            return i
    raise KeyError(key)


def locate_yaml_path(lines: list[str], path: tuple[str, ...]) -> int:
    indent = 0
    start = 0
    end = len(lines)
    for position, key in enumerate(path):
        line_index = find_key_line(lines, key, indent, start, end)
        if position == len(path) - 1:
            return line_index
        start = line_index + 1
        end = block_end(lines, line_index)
        indent = child_indent(lines, line_index)
    raise KeyError(dotted(path))


def double_quote(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def single_quote(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def numeric_like(value: str) -> bool:
    return bool(re.fullmatch(r"-?\d+(?:\.\d+)?", value))


def format_scalar(value: object, current_token: str) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)

    text = str(value)
    token = current_token.strip()

    if token.startswith('"') and token.endswith('"'):
        return double_quote(text)
    if token.startswith("'") and token.endswith("'"):
        return single_quote(text)

    if SAFE_UNQUOTED.fullmatch(text) and text.lower() not in RESERVED_SCALARS and not numeric_like(text):
        return text
    return double_quote(text)


def update_yaml_scalar(text: str, path: tuple[str, ...], value: object) -> str:
    lines = text.splitlines()
    line_index = locate_yaml_path(lines, path)
    line = lines[line_index]
    head, separator, tail = line.partition(":")
    if not separator:
        raise KeyError(dotted(path))

    value_match = YAML_VALUE_LINE.match(tail)
    if not value_match:
        raise ValueError(f"Unable to update scalar at {dotted(path)}")

    space = value_match.group("space")
    comment = value_match.group("comment") or ""
    current_token = (value_match.group("value") or "").rstrip()
    rendered = format_scalar(value, current_token)
    if not space:
        space = " "

    lines[line_index] = f"{head}:{space}{rendered}{comment}"
    trailing_newline = "\n" if text.endswith("\n") else ""
    return "\n".join(lines) + trailing_newline


def collect_sync_changes(manifest: Manifest) -> list[dict[str, object]]:
    yaml_cache: dict[Path, dict] = {}
    changes: list[dict[str, object]] = []

    for image_name, bindings in SYNC_BINDINGS.items():
        desired = manifest.images[image_name]
        for binding in bindings:
            file_path = REPO_ROOT / binding.file_path
            data = yaml_cache.get(file_path)
            if data is None:
                data = yaml_load(file_path)
                yaml_cache[file_path] = data

            current_repository = str(get_nested_value(data, binding.repository_path))
            current_tag = str(get_nested_value(data, binding.tag_path))

            if current_repository != desired.repository:
                changes.append(
                    {
                        "file": file_path,
                        "path": binding.repository_path,
                        "old": current_repository,
                        "new": desired.repository,
                        "image": image_name,
                    }
                )
            if current_tag != desired.tag:
                changes.append(
                    {
                        "file": file_path,
                        "path": binding.tag_path,
                        "old": current_tag,
                        "new": desired.tag,
                        "image": image_name,
                    }
                )

    return changes


def print_sync_changes(changes: list[dict[str, object]]) -> None:
    if not changes:
        print("Helm image values are already in sync.")
        return

    print("Pending sync changes:")
    for change in changes:
        file_path = Path(change["file"])
        print(
            f"- {file_path.relative_to(REPO_ROOT)} :: {dotted(change['path'])} "
            f"{change['old']} -> {change['new']}"
        )


def sync_values(manifest: Manifest, check_only: bool = False) -> int:
    changes = collect_sync_changes(manifest)
    print_sync_changes(changes)
    if not changes:
        return 0
    if check_only:
        return 1

    grouped: dict[Path, list[dict[str, object]]] = {}
    for change in changes:
        grouped.setdefault(Path(change["file"]), []).append(change)

    for file_path, file_changes in grouped.items():
        original = file_path.read_text(encoding="utf-8")
        updated = original
        for change in file_changes:
            updated = update_yaml_scalar(updated, change["path"], change["new"])
        if updated != original:
            file_path.write_text(updated, encoding="utf-8")

    print(f"Updated {len(grouped)} Helm values file(s).")
    return 0


def make_fresh_dev_tag(tag: str, stamp: str) -> str:
    match = DEV_TAG_SUFFIX.match(tag)
    base = match.group("base") if match else tag
    return f"{base}-dev-{stamp}"


def refresh_manifest_tags(manifest: Manifest, components: list[str], stamp: str) -> Manifest:
    manifest_text = manifest.manifest_path.read_text(encoding="utf-8")
    changes: list[tuple[str, str, str]] = []

    for component in components:
        if component == "plugins":
            continue
        if component not in manifest.images:
            raise ValueError(f"manifest is missing image metadata for component: {component}")

        current_tag = manifest.images[component].tag
        next_tag = make_fresh_dev_tag(current_tag, stamp)
        if current_tag == next_tag:
            continue

        manifest_text = update_yaml_scalar(manifest_text, ("images", component, "tag"), next_tag)
        changes.append((component, current_tag, next_tag))

    if not changes:
        return manifest

    manifest.manifest_path.write_text(manifest_text, encoding="utf-8")
    print(f"Updated manifest tags with dev stamp {stamp}:")
    for component, old_tag, new_tag in changes:
        print(f"- {component}: {old_tag} -> {new_tag}")

    return load_manifest(manifest.manifest_path)


def shell_join(command: list[str]) -> str:
    return shlex.join([str(part) for part in command])


def run(command: list[str], *, env: dict[str, str] | None = None, cwd: Path = REPO_ROOT) -> None:
    printable = shell_join(command)
    print(f"+ {printable}")
    subprocess.run(command, cwd=cwd, env=env, check=True)


def run_capture(
    command: list[str],
    *,
    cwd: Path = REPO_ROOT,
    timeout: float | None = None,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=cwd,
        text=True,
        capture_output=True,
        timeout=timeout,
        check=False,
    )


def env_with_overrides(*, build_components: str | None = None, minikube_profile: str | None = None) -> dict[str, str]:
    env = os.environ.copy()
    if build_components:
        env["BUILD_COMPONENTS"] = build_components
    if minikube_profile:
        env["MINIKUBE_PROFILE"] = minikube_profile
    return env


def resolve_components(manifest: Manifest, override: str | None) -> list[str]:
    if override:
        components = normalize_components(override)
    else:
        components = manifest.build_components
    if not components:
        raise ValueError("No build components were resolved")
    return components


def maybe_refresh_tags(
    manifest: Manifest,
    components: list[str],
    *,
    fresh_tags: bool,
    stamp: str | None,
) -> Manifest:
    if not fresh_tags:
        return manifest

    resolved_stamp = stamp or datetime.now().strftime("%Y%m%d%H%M%S")
    return refresh_manifest_tags(manifest, components, resolved_stamp)


def minikube_profile(manifest: Manifest, override: str | None) -> str:
    value = override or str(manifest.minikube.get("profile", "minikube")).strip()
    if not value:
        raise ValueError("minikube.profile must not be empty")
    return value


def ensure_minikube_started(manifest: Manifest, override_profile: str | None = None) -> str:
    profile = minikube_profile(manifest, override_profile)
    command = ["minikube", "start", "-p", profile]

    driver = str(manifest.minikube.get("driver", "")).strip()
    if driver:
        command.append(f"--driver={driver}")

    cpus = manifest.minikube.get("cpus")
    if cpus not in (None, ""):
        command.append(f"--cpus={cpus}")

    memory = manifest.minikube.get("memory")
    if memory not in (None, ""):
        command.append(f"--memory={memory}")

    disk_size = str(manifest.minikube.get("diskSize", "")).strip()
    if disk_size:
        command.append(f"--disk-size={disk_size}")

    run(command)
    run(["minikube", "-p", profile, "update-context"])
    run(["kubectl", "config", "use-context", profile])

    addons = manifest.minikube.get("addons") or []
    if not isinstance(addons, list):
        raise ValueError("minikube.addons must be a list")
    for addon in addons:
        addon_name = str(addon).strip()
        if addon_name:
            run(["minikube", "-p", profile, "addons", "enable", addon_name])

    run(["minikube", "-p", profile, "status"])
    return profile


def print_show(manifest: Manifest) -> int:
    print(f"Manifest     : {manifest.manifest_path.relative_to(REPO_ROOT)}")
    print(f"Chart        : {manifest.chart_dir.relative_to(REPO_ROOT)}")
    print(f"Dev Config   : {manifest.dev_config_file.relative_to(REPO_ROOT)}")
    print(f"Minikube LB  : {manifest.local_values_file.relative_to(REPO_ROOT)}")
    print(f"Release      : {manifest.release_name}")
    print(f"Namespace    : {manifest.namespace}")
    print(f"Components   : {', '.join(manifest.build_components)}")
    print(f"Minikube     : profile={minikube_profile(manifest, None)}")
    print("Images:")
    for name, spec in manifest.images.items():
        print(f"- {name}: {spec.repository}:{spec.tag}")

    print("Sync Targets:")
    synced_files = sorted({binding.file_path for bindings in SYNC_BINDINGS.values() for binding in bindings})
    for file_path in synced_files:
        print(f"- {file_path}")
    bind_address, mappings = load_dev_port_forward_config(manifest.dev_config_file)
    print(f"Port Forward ({bind_address}):")
    for mapping in mappings:
        print(f"- {mapping.local_port} -> {mapping.service}:{mapping.remote_port}")
    return 0


def cmd_show(args: argparse.Namespace, manifest: Manifest) -> int:
    del args
    return print_show(manifest)


def cmd_sync(args: argparse.Namespace, manifest: Manifest) -> int:
    return sync_values(manifest, check_only=args.check)


def cmd_build(args: argparse.Namespace, manifest: Manifest) -> int:
    components = resolve_components(manifest, args.components)
    manifest = maybe_refresh_tags(
        manifest,
        components,
        fresh_tags=args.fresh_tags,
        stamp=args.stamp,
    )

    if not args.skip_sync or args.fresh_tags:
        rc = sync_values(manifest)
        if rc != 0:
            return rc

    run(
        [
            str(REPO_ROOT / "higress" / "helm" / "build-local-images.sh"),
            "--components",
            ",".join(components),
        ]
    )
    return 0


def cmd_minikube_start(args: argparse.Namespace, manifest: Manifest) -> int:
    ensure_minikube_started(manifest, args.profile)
    return 0


def cmd_minikube_dev(args: argparse.Namespace, manifest: Manifest) -> int:
    components = resolve_components(manifest, args.components)
    manifest = maybe_refresh_tags(
        manifest,
        components,
        fresh_tags=args.fresh_tags,
        stamp=args.stamp,
    )

    if not args.skip_sync or args.fresh_tags:
        rc = sync_values(manifest)
        if rc != 0:
            return rc

    profile = minikube_profile(manifest, args.profile)
    if not args.skip_start:
        profile = ensure_minikube_started(manifest, profile)

    env = env_with_overrides(build_components=",".join(components), minikube_profile=profile)
    run([str(REPO_ROOT / "start.sh"), "dev-redeploy"], env=env)
    return 0


def cmd_minikube_tunnel(args: argparse.Namespace, manifest: Manifest) -> int:
    components = resolve_components(manifest, args.components)
    manifest = maybe_refresh_tags(
        manifest,
        components,
        fresh_tags=args.fresh_tags,
        stamp=args.stamp,
    )

    if not args.skip_sync or args.fresh_tags:
        rc = sync_values(manifest)
        if rc != 0:
            return rc

    profile = minikube_profile(manifest, args.profile)
    if not args.skip_start:
        profile = ensure_minikube_started(manifest, profile)

    env = env_with_overrides(build_components=",".join(components), minikube_profile=profile)
    run(
        [
            str(REPO_ROOT / "higress" / "helm" / "redeploy-minikube.sh"),
            "--values",
            str(manifest.local_values_file),
            "--namespace",
            manifest.namespace,
            "--release",
            manifest.release_name,
            "--profile",
            profile,
            "--components",
            ",".join(components),
        ],
        env=env,
    )

    if args.start_tunnel:
        run(["minikube", "-p", profile, "tunnel"])
    else:
        print(f"Run `minikube -p {profile} tunnel` in another terminal to expose LoadBalancer services.")
    return 0


def parse_host_port(value: str, default_port: int) -> tuple[str, int]:
    text = str(value).strip()
    if not text:
        return "127.0.0.1", default_port
    if text.startswith("["):
        host, sep, port = text[1:].partition("]:")
        if sep:
            return host, int(port)
        return host, default_port
    if text.count(":") == 1:
        host, port = text.rsplit(":", 1)
        return host, int(port)
    return text, default_port


def parse_mysql_target(dsn: str) -> tuple[str, int]:
    match = MYSQL_DSN_TCP.search(dsn)
    if match:
        return parse_host_port(match.group("target"), 3306)
    return "127.0.0.1", 3306


def tcp_connect(host: str, port: int, timeout: float) -> socket.socket:
    sock = socket.create_connection((host, port), timeout=timeout)
    sock.settimeout(timeout)
    return sock


def check_mysql(config: dict[str, object], timeout: float) -> CheckResult:
    dsn = str(config.get("dsn") or "").strip()
    enabled = bool(config.get("enabled"))
    host, port = parse_mysql_target(dsn) if dsn else ("127.0.0.1", 3306)
    note = "configured dsn" if dsn else "default dev endpoint"
    try:
        with tcp_connect(host, port, timeout) as sock:
            handshake = sock.recv(64)
        if len(handshake) < 5:
            return CheckResult("mysql", True, "failed", f"{host}:{port} connected but handshake was too short")
        protocol = handshake[4]
        if protocol != 10:
            return CheckResult("mysql", True, "failed", f"{host}:{port} connected but protocol byte was {protocol}")
        detail = f"{host}:{port} reachable via MySQL handshake ({note})"
        if not enabled:
            detail = f"{detail}; clients.portaldb.enabled=false"
        return CheckResult("mysql", True, "ok", detail)
    except OSError as exc:
        return CheckResult("mysql", True, "failed", f"{host}:{port} unreachable ({note}): {exc}")


def check_redis(host: str, port: int, timeout: float) -> CheckResult:
    try:
        with tcp_connect(host, port, timeout) as sock:
            sock.sendall(b"*1\r\n$4\r\nPING\r\n")
            response = sock.recv(64)
        if response.startswith(b"+PONG"):
            return CheckResult("redis", True, "ok", f"{host}:{port} responded to PING")
        return CheckResult("redis", True, "failed", f"{host}:{port} returned {response!r}")
    except OSError as exc:
        return CheckResult("redis", True, "failed", f"{host}:{port} unreachable: {exc}")


def check_grafana(config: dict[str, object], timeout: float) -> CheckResult:
    base_url = str(config.get("base_url") or "http://127.0.0.1:3000").strip() or "http://127.0.0.1:3000"
    enabled = bool(config.get("enabled"))
    parsed = urlparse(base_url)
    if not parsed.scheme or not parsed.netloc:
        return CheckResult("grafana", False, "failed", f"invalid baseURL: {base_url}")
    path = parsed.path.rstrip("/") + "/api/health"
    if not path.startswith("/"):
        path = "/" + path
    connection_cls = http.client.HTTPSConnection if parsed.scheme == "https" else http.client.HTTPConnection
    try:
        conn = connection_cls(parsed.hostname, parsed.port, timeout=timeout)
        conn.request("GET", path)
        response = conn.getresponse()
        status = response.status
        response.read()
        conn.close()
    except OSError as exc:
        return CheckResult("grafana", False, "failed", f"{base_url} unreachable: {exc}")

    if 200 <= status < 400 or status in {401, 403}:
        detail = f"{base_url} reachable (HTTP {status})"
        if not enabled:
            detail = f"{detail}; clients.grafana.enabled=false"
        return CheckResult("grafana", False, "ok", detail)
    return CheckResult("grafana", False, "failed", f"{base_url} returned HTTP {status}")


def kubectl_command(base: dict[str, object], *args: str) -> list[str]:
    command = [str(base["kubectl_bin"])]
    kubeconfig = str(base.get("kubeconfig") or "").strip()
    if kubeconfig:
        command.extend(["--kubeconfig", kubeconfig])
    command.extend(args)
    return command


def check_k8s(config: dict[str, object], timeout: float) -> CheckResult:
    namespace = str(config.get("namespace") or "aigateway-system").strip() or "aigateway-system"
    context_cmd = kubectl_command(config, "config", "current-context")
    context_result = run_capture(context_cmd, timeout=timeout)
    if context_result.returncode != 0:
        detail = context_result.stderr.strip() or context_result.stdout.strip() or "unable to resolve kubectl context"
        return CheckResult("k8s", True, "failed", detail)

    namespace_cmd = kubectl_command(config, "get", "namespace", namespace, "-o", "name")
    namespace_result = run_capture(namespace_cmd, timeout=timeout)
    if namespace_result.returncode != 0:
        detail = namespace_result.stderr.strip() or namespace_result.stdout.strip() or f"namespace {namespace} is unavailable"
        return CheckResult("k8s", True, "failed", detail)

    configmap_cmd = kubectl_command(config, "-n", namespace, "get", "configmap", "higress-config", "-o", "name")
    configmap_result = run_capture(configmap_cmd, timeout=timeout)
    if configmap_result.returncode != 0:
        detail = configmap_result.stderr.strip() or configmap_result.stdout.strip() or "higress-config read failed"
        return CheckResult("k8s", True, "failed", detail)

    resource_cmd = kubectl_command(
        config,
        "-n",
        namespace,
        "get",
        "configmap",
        "-l",
        "console.aigateway.io/type=resource",
        "--ignore-not-found",
        "-o",
        "name",
    )
    resource_result = run_capture(resource_cmd, timeout=timeout)
    if resource_result.returncode != 0:
        detail = resource_result.stderr.strip() or resource_result.stdout.strip() or "resource projection query failed"
        return CheckResult("k8s", True, "failed", detail)

    api_resources_cmd = kubectl_command(config, "api-resources", "-o", "name")
    api_resources_result = run_capture(api_resources_cmd, timeout=timeout)
    if api_resources_result.returncode != 0:
        detail = api_resources_result.stderr.strip() or api_resources_result.stdout.strip() or "api-resources query failed"
        return CheckResult("k8s", True, "failed", detail)

    api_resources = {line.strip() for line in api_resources_result.stdout.splitlines() if line.strip()}
    required_resources = {
        "wasmplugins.extensions.higress.io",
        "mcpbridges.networking.higress.io",
        "http2rpcs.networking.higress.io",
    }
    missing_resources = sorted(required_resources - api_resources)
    if missing_resources:
        return CheckResult("k8s", True, "failed", f"missing Higress API resources: {', '.join(missing_resources)}")

    context = context_result.stdout.strip() or "<unknown>"
    resource_count = len([line for line in resource_result.stdout.splitlines() if line.strip()])
    detail = (
        f"context={context}, namespace={namespace}, higress-config readable, "
        f"projected resources={resource_count}, higress api-resources ok"
    )
    if not bool(config.get("enabled")):
        detail = f"{detail}; clients.k8s.enabled=false"
    return CheckResult("k8s", True, "ok", detail)


def format_check_results(results: list[CheckResult]) -> str:
    headers = ("Check", "Required", "Status", "Detail")
    rows = [(item.name, "yes" if item.required else "no", item.status, item.detail) for item in results]
    widths = [len(header) for header in headers]
    for row in rows:
        for index, value in enumerate(row):
            widths[index] = max(widths[index], len(value))

    def render_row(values: tuple[str, str, str, str]) -> str:
        return "  ".join(value.ljust(widths[index]) for index, value in enumerate(values))

    lines = [render_row(headers), render_row(tuple("-" * width for width in widths))]
    for row in rows:
        lines.append(render_row(row))
    return "\n".join(lines)


def cmd_check_connectivity(args: argparse.Namespace, manifest: Manifest) -> int:
    del manifest
    backend_config_path = Path(args.backend_config)
    if not backend_config_path.is_absolute():
        backend_config_path = (REPO_ROOT / backend_config_path).resolve()
    backend_cfg = read_backend_client_config(backend_config_path)

    results = [
        check_k8s(backend_cfg["k8s"], args.timeout),
        check_mysql(backend_cfg["portaldb"], args.timeout),
        check_grafana(backend_cfg["grafana"], args.timeout),
        check_redis(args.redis_host, args.redis_port, args.timeout),
    ]

    print(format_check_results(results))
    failures = [item for item in results if item.status != "ok" and (item.required or args.fail_on_environment)]
    return 1 if failures else 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Unified local version sync, image build, and minikube helper for aigateway-group."
    )
    parser.add_argument(
        "--manifest",
        default=str(DEFAULT_MANIFEST),
        help="Path to the central image version manifest.",
    )

    subparsers = parser.add_subparsers(dest="command", required=True)

    show_parser = subparsers.add_parser("show", help="Show the current manifest and sync targets.")
    show_parser.set_defaults(handler=cmd_show)

    connectivity_parser = subparsers.add_parser(
        "check-connectivity",
        help="Check local development connectivity for console dependencies and backing services.",
    )
    connectivity_parser.add_argument(
        "--backend-config",
        default="aigateway-console/backend/hack/config.yaml",
        help="Path to the console backend config file.",
    )
    connectivity_parser.add_argument(
        "--redis-host",
        default="127.0.0.1",
        help="Redis host used for the local environment probe.",
    )
    connectivity_parser.add_argument(
        "--redis-port",
        type=int,
        default=6379,
        help="Redis port used for the local environment probe.",
    )
    connectivity_parser.add_argument(
        "--timeout",
        type=float,
        default=5.0,
        help="Per-check timeout in seconds.",
    )
    connectivity_parser.add_argument(
        "--fail-on-environment",
        action="store_true",
        help="Also fail when optional environment checks such as Redis or Grafana do not pass.",
    )
    connectivity_parser.set_defaults(handler=cmd_check_connectivity)

    sync_parser = subparsers.add_parser("sync", help="Sync image versions into Helm values files.")
    sync_parser.add_argument(
        "--check",
        action="store_true",
        help="Only check whether Helm values already match the manifest.",
    )
    sync_parser.set_defaults(handler=cmd_sync)

    build_parser = subparsers.add_parser("build", help="Sync values and build all configured local images.")
    build_parser.add_argument(
        "--components",
        help="Comma-separated component list. Defaults to defaults.buildComponents.",
    )
    build_parser.add_argument(
        "--skip-sync",
        action="store_true",
        help="Skip syncing Helm values before building images.",
    )
    build_parser.add_argument(
        "--fresh-tags",
        action="store_true",
        help="Stamp the selected image tags with a fresh local dev suffix before syncing and building.",
    )
    build_parser.add_argument(
        "--stamp",
        help="Optional YYYYMMDDHHMMSS-style suffix used with --fresh-tags.",
    )
    build_parser.set_defaults(handler=cmd_build)

    minikube_start_parser = subparsers.add_parser("minikube-start", help="Start the local minikube cluster.")
    minikube_start_parser.add_argument(
        "--profile",
        help="Override minikube.profile from the manifest.",
    )
    minikube_start_parser.set_defaults(handler=cmd_minikube_start)

    minikube_dev_parser = subparsers.add_parser(
        "minikube-dev",
        help="Sync values, ensure minikube is running, then run the dev-redeploy flow.",
    )
    minikube_dev_parser.add_argument(
        "--profile",
        help="Override minikube.profile from the manifest.",
    )
    minikube_dev_parser.add_argument(
        "--components",
        help="Comma-separated component list. Defaults to defaults.buildComponents.",
    )
    minikube_dev_parser.add_argument(
        "--skip-sync",
        action="store_true",
        help="Skip syncing Helm values before redeploying.",
    )
    minikube_dev_parser.add_argument(
        "--skip-start",
        action="store_true",
        help="Assume minikube is already running and keep the current cluster untouched.",
    )
    minikube_dev_parser.add_argument(
        "--fresh-tags",
        action="store_true",
        help="Stamp the selected image tags with a fresh local dev suffix before syncing and redeploying.",
    )
    minikube_dev_parser.add_argument(
        "--stamp",
        help="Optional YYYYMMDDHHMMSS-style suffix used with --fresh-tags.",
    )
    minikube_dev_parser.set_defaults(handler=cmd_minikube_dev)

    minikube_tunnel_parser = subparsers.add_parser(
        "minikube-tunnel",
        help="Sync values, redeploy the LoadBalancer profile, and optionally start minikube tunnel.",
    )
    minikube_tunnel_parser.add_argument(
        "--profile",
        help="Override minikube.profile from the manifest.",
    )
    minikube_tunnel_parser.add_argument(
        "--components",
        help="Comma-separated component list. Defaults to defaults.buildComponents.",
    )
    minikube_tunnel_parser.add_argument(
        "--skip-sync",
        action="store_true",
        help="Skip syncing Helm values before redeploying.",
    )
    minikube_tunnel_parser.add_argument(
        "--skip-start",
        action="store_true",
        help="Assume minikube is already running and keep the current cluster untouched.",
    )
    minikube_tunnel_parser.add_argument(
        "--start-tunnel",
        action="store_true",
        help="Start `minikube tunnel` after the redeploy finishes.",
    )
    minikube_tunnel_parser.add_argument(
        "--fresh-tags",
        action="store_true",
        help="Stamp the selected image tags with a fresh local dev suffix before syncing and redeploying.",
    )
    minikube_tunnel_parser.add_argument(
        "--stamp",
        help="Optional YYYYMMDDHHMMSS-style suffix used with --fresh-tags.",
    )
    minikube_tunnel_parser.set_defaults(handler=cmd_minikube_tunnel)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    manifest_path = Path(args.manifest)
    if not manifest_path.is_absolute():
        manifest_path = (REPO_ROOT / manifest_path).resolve()

    try:
        manifest = load_manifest(manifest_path)
        handler = args.handler
        return handler(args, manifest)
    except subprocess.CalledProcessError as exc:
        return fail(f"command failed with exit code {exc.returncode}: {shell_join(exc.cmd)}")
    except (KeyError, ValueError, FileNotFoundError) as exc:
        return fail(str(exc))


if __name__ == "__main__":
    raise SystemExit(main())
