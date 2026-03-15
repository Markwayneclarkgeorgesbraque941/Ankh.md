#!/usr/bin/env python3
"""Inject get_agent_identity() into hermes_cli/config.py (runs after directory.patch)."""
import sys

OLD_NO_DOCSTRING = '''def get_sticker_cache_dir() -> Path:
    return get_ankh_scope_root() / "sticker_cache.json"


def _secure_dir(path):'''

OLD_WITH_DOCSTRING = '''def get_sticker_cache_dir() -> Path:
    """Get sticker cache directory (scoped)."""
    return get_ankh_scope_root() / "sticker_cache.json"


def _secure_dir(path):'''

NEW = '''def get_sticker_cache_dir() -> Path:
    """Get sticker cache file path (scoped)."""
    return get_ankh_scope_root() / "sticker_cache.json"


def _strip_jsonc(text: str) -> str:
    """Strip // and /* */ comments for JSONC parsing."""
    import re
    text = re.sub(r'//[^\\n]*', '', text)
    text = re.sub(r'/\\*.*?\\*/', '', text, flags=re.DOTALL)
    return text


def get_agent_identity() -> Tuple[Optional[str], Optional[str]]:
    """Return (uuid, title) from .agent/agent.jsonc when in local scope.

    When uuid is missing, auto-assigns UUIDv7 and persists to agent.jsonc.
    When title is missing, defaults to "A Wandering Agent".
    Returns (None, None) when in global scope or no .agent project.
    mainframe must be "hermes"; openclaw, agent, and others are not supported.
    """
    import json
    import uuid
    if os.getenv("HERMES_ANKH_SCOPE") == "global":
        return (None, None)
    local = find_agent_dir()
    if local is None:
        return (None, None)
    manifest_path = local / "agent.jsonc"
    if not manifest_path.exists():
        return (None, None)
    try:
        with open(manifest_path, encoding="utf-8") as f:
            text = f.read()
    except Exception:
        return (None, None)
    try:
        manifest = json.loads(_strip_jsonc(text))
    except Exception:
        return (None, None)
    manifest = manifest if isinstance(manifest, dict) else {}
    mainframe = manifest.get("mainframe")
    if mainframe is not None and mainframe != "hermes":
        raise ValueError(f"mainframe '{mainframe}' is not supported; only 'hermes' is supported")
    agent_uuid = manifest.get("uuid")
    if not agent_uuid or not isinstance(agent_uuid, str):
        agent_uuid = str(getattr(uuid, "uuid7", uuid.uuid4)())
        manifest["uuid"] = agent_uuid
        if mainframe is None:
            manifest["mainframe"] = "hermes"
        try:
            with open(manifest_path, "w", encoding="utf-8") as f:
                json.dump(manifest, f, indent="\\t")
        except Exception:
            pass
    title = manifest.get("title")
    if not title or not isinstance(title, str):
        title = "A Wandering Agent"
    return (agent_uuid, title)


def get_agent_prompt() -> Optional[str]:
    """Return the prompt from .agent/agent.jsonc when in local scope, else None."""
    import json
    if os.getenv("HERMES_ANKH_SCOPE") == "global":
        return None
    local = find_agent_dir()
    if local is None:
        return None
    manifest_path = local / "agent.jsonc"
    if not manifest_path.exists():
        return None
    try:
        with open(manifest_path, encoding="utf-8") as f:
            text = f.read()
    except Exception:
        return None
    try:
        manifest = json.loads(_strip_jsonc(text))
    except Exception:
        return None
    manifest = manifest if isinstance(manifest, dict) else {}
    prompt = manifest.get("prompt")
    return prompt if isinstance(prompt, str) and prompt.strip() else None


def _secure_dir(path):'''


# Fallback for Python < 3.12 (uuid7 added in 3.12)
OLD_UUID7 = "agent_uuid = str(uuid.uuid7())"
NEW_UUID7 = 'agent_uuid = str(getattr(uuid, "uuid7", uuid.uuid4)())'


OLD_ANKH = '''def get_agent_identity() -> Tuple[Optional[str], Optional[str]]:
    """Return (uuid, title) from .agent/ankh.yaml when in local scope.

    When agent.uuid is missing, auto-assigns UUIDv7 and persists to ankh.yaml.
    When agent.title is missing, defaults to "A Wandering Agent".
    Returns (None, None) when in global scope or no .agent project.
    """
    import uuid
    if os.getenv("HERMES_ANKH_SCOPE") == "global":
        return (None, None)
    local = find_agent_dir()
    if local is None:
        return (None, None)
    manifest_path = local / "ankh.yaml"
    if not manifest_path.exists():
        return (None, None)
    try:
        with open(manifest_path, encoding="utf-8") as f:
            manifest = yaml.safe_load(f) or {}
    except Exception:
        return (None, None)
    manifest = manifest if isinstance(manifest, dict) else {}
    agent = manifest.get("agent") or {}
    agent = agent if isinstance(agent, dict) else {}
    agent_uuid = agent.get("uuid")
    if not agent_uuid or not isinstance(agent_uuid, str):
        agent_uuid = str(getattr(uuid, "uuid7", uuid.uuid4)())
        manifest["agent"] = agent
        agent["uuid"] = agent_uuid
        try:
            with open(manifest_path, "w", encoding="utf-8") as f:
                yaml.dump(manifest, f, default_flow_style=False, sort_keys=False)
        except Exception:
            pass
    title = agent.get("title")
    if not title or not isinstance(title, str):
        title = "A Wandering Agent"
    return (agent_uuid, title)


def _secure_dir(path):'''

NEW_AGENT_JSONC = '''def _strip_jsonc(text: str) -> str:
    """Strip // and /* */ comments for JSONC parsing."""
    import re
    text = re.sub(r'//[^\\n]*', '', text)
    text = re.sub(r'/\\*.*?\\*/', '', text, flags=re.DOTALL)
    return text


def get_agent_identity() -> Tuple[Optional[str], Optional[str]]:
    """Return (uuid, title) from .agent/agent.jsonc when in local scope.

    When uuid is missing, auto-assigns UUIDv7 and persists to agent.jsonc.
    When title is missing, defaults to "A Wandering Agent".
    Returns (None, None) when in global scope or no .agent project.
    mainframe must be "hermes"; openclaw, agent, and others are not supported.
    """
    import json
    import uuid
    if os.getenv("HERMES_ANKH_SCOPE") == "global":
        return (None, None)
    local = find_agent_dir()
    if local is None:
        return (None, None)
    manifest_path = local / "agent.jsonc"
    if not manifest_path.exists():
        return (None, None)
    try:
        with open(manifest_path, encoding="utf-8") as f:
            text = f.read()
    except Exception:
        return (None, None)
    try:
        manifest = json.loads(_strip_jsonc(text))
    except Exception:
        return (None, None)
    manifest = manifest if isinstance(manifest, dict) else {}
    mainframe = manifest.get("mainframe")
    if mainframe is not None and mainframe != "hermes":
        raise ValueError(f"mainframe '{mainframe}' is not supported; only 'hermes' is supported")
    agent_uuid = manifest.get("uuid")
    if not agent_uuid or not isinstance(agent_uuid, str):
        agent_uuid = str(getattr(uuid, "uuid7", uuid.uuid4)())
        manifest["uuid"] = agent_uuid
        if mainframe is None:
            manifest["mainframe"] = "hermes"
        try:
            with open(manifest_path, "w", encoding="utf-8") as f:
                json.dump(manifest, f, indent="\\t")
        except Exception:
            pass
    title = manifest.get("title")
    if not title or not isinstance(title, str):
        title = "A Wandering Agent"
    return (agent_uuid, title)


def get_agent_prompt() -> Optional[str]:
    """Return the prompt from .agent/agent.jsonc when in local scope, else None."""
    import json
    if os.getenv("HERMES_ANKH_SCOPE") == "global":
        return None
    local = find_agent_dir()
    if local is None:
        return None
    manifest_path = local / "agent.jsonc"
    if not manifest_path.exists():
        return None
    try:
        with open(manifest_path, encoding="utf-8") as f:
            text = f.read()
    except Exception:
        return None
    try:
        manifest = json.loads(_strip_jsonc(text))
    except Exception:
        return None
    manifest = manifest if isinstance(manifest, dict) else {}
    prompt = manifest.get("prompt")
    return prompt if isinstance(prompt, str) and prompt.strip() else None


def _secure_dir(path):'''


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "hermes_cli/config.py"
    with open(path, encoding="utf-8") as f:
        s = f.read()
    changed = False
    if "manifest_path = local / \"agent.jsonc\"" not in s:
        if OLD_ANKH in s:
            s = s.replace(OLD_ANKH, NEW_AGENT_JSONC)
            changed = True
        elif OLD_WITH_DOCSTRING in s:
            s = s.replace(OLD_WITH_DOCSTRING, NEW)
            changed = True
        elif OLD_NO_DOCSTRING in s:
            s = s.replace(OLD_NO_DOCSTRING, NEW)
            changed = True
        if OLD_UUID7 in s:
            s = s.replace(OLD_UUID7, NEW_UUID7)
            changed = True
        if not changed:
            print(f"Agent identity block not found in {path}", file=sys.stderr)
            sys.exit(1)

    # Inject agent.jsonc prompt into load_config when not already present
    load_config_injection = """            except Exception as e:
                print(f"Warning: Failed to load config from {config_path}: {e}")
    # Inject agent.jsonc prompt as agent.system_prompt when in Ankh scope
    try:
        prompt = get_agent_prompt()
        if prompt:
            if "agent" not in config:
                config["agent"] = {}
            _, title = get_agent_identity()
            title = title or "A Wandering Agent"
            cwd = str(Path(os.getcwd()).resolve())
            _esc = lambda s: (s or "").replace("&", "&amp;").replace('"', "&quot;")
            parts = [
                f'<identity><title v="{_esc(title)}" /></identity>',
                '',
                f'<environment><path v="{_esc(cwd)}" /></environment>',
                '',
                prompt.strip()
            ]
            config["agent"]["system_prompt"] = "\\n".join(parts)
    except Exception:
        pass
    return _normalize_max_turns_config(config)"""
    load_config_needle = """            except Exception as e:
                print(f"Warning: Failed to load config from {config_path}: {e}")
    return _normalize_max_turns_config(config)"""
    if load_config_needle in s and "prompt = get_agent_prompt()" not in s:
        s = s.replace(load_config_needle, load_config_injection)
        changed = True

    with open(path, "w", encoding="utf-8") as f:
        f.write(s)
    print(f"Applied agent_identity to {path}", file=sys.stderr)


if __name__ == "__main__":
    main()
