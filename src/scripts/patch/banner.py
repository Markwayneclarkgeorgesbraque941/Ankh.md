#!/usr/bin/env python3
"""Apply inline serpent + compact left panel for Ankh mode (runs after banner.patch)."""
import json
import sys
from pathlib import Path

OLD_LOGO = '''HERMES_AGENT_LOGO_ANKH = """[bold #FFD700]╦ ╦╔═╗╦═╗╔╦╗╔═╗╔═╗  ╔═╗╔═╗╔═╗╔╗╔╔╦╗[/]
[#FFBF00]╠═╣║╣ ╠╦╝║║║║╣ ╚═╗  ╠═╣║ ╦║╣ ║║║ ║ [/]
[#CD7F32]╩ ╩╚═╝╩╚═╩ ╩╚═╝╚═╝  ╩ ╩╚═╝╚═╝╝╚╝ ╩ [/]"""'''

# Match _build_ankh_banner from banner.patch (replaced by apply_banner_ankh)
OLD_ANKH_BANNER_BUILD = '''def _build_ankh_banner() -> str:
    """Build Ankh banner with text left, scepter+ankh icons far-right, blank line after."""
    import shutil
    t1 = "[bold #FFD700]█  █ █▀▀▀ █▀▀▄ █▄ ▄█ █▀▀▀ ▄▀▀▀     ▄▀▀▄ ▄▀▀▀ █▀▀▀ █▄  █ ▀▀█▀▀[/]"
    t2 = "[#FFBF00]█▀▀█ █▀▀  █▀█  █ ▀ █ █▀▀   ▀▀▄     █▀▀█ █ ▀█ █▀▀  █ ▀▄█   █  [/]"
    t3 = "[#CD7F32]█  █ █▄▄▄ █  █ █   █ █▄▄▄ ▀▄▄▀     █  █ ▀▄▄▀ █▄▄▄ █   █   █ [/]"
    c1 = "[#FFD700]⠠⠶⢾⣿⣿⡷⠶⠄[/] [#FFD700]⡠⢄[/]"
    c2 = "[#FFBF00]⠀⠀⠈⣿⣿⠁⠀⠀[/] [#FFBF00]⣿⣿[/]"
    c3 = "[#CD7F32]⠀⠀⠀⠾⠷⠀⠀⠀[/] [#CD7F32]⠇⠸[/]"
    w = shutil.get_terminal_size().columns
    pad1 = max(0, w - 61 - 11)
    pad2 = max(0, w - 60 - 11)
    return "\\n".join([
        t1 + " " * pad1 + c1,
        t2 + " " * pad1 + c2,
        t3 + " " * pad2 + c3,
    ])'''

# HERMES AGENT left, versions, ankh/scepter on far right (from banner.patch)
# __ANKH_VERSION__, __HERMES_VERSION__, __HERMES_GITHUB_URL__ replaced at apply time
# enable_links=False avoids OSC 8 corruption when rendered via ChatConsole (e.g. /clear)
NEW_ANKH_BANNER_BUILD_TEMPLATE = '''def _build_ankh_banner(enable_links: bool = True) -> str:
    """Build Ankh banner with HERMES AGENT left, versions, ankh/scepter far-right."""
    import shutil
    t1 = "[bold #FFD700]█  █ █▀▀▀ █▀▀▄ █▄ ▄█ █▀▀▀ ▄▀▀▀     ▄▀▀▄ ▄▀▀▀ █▀▀▀ █▄  █ ▀▀█▀▀[/]"
    t2 = "[#FFBF00]█▀▀█ █▀▀  █▀█  █ ▀ █ █▀▀   ▀▀▄     █▀▀█ █ ▀█ █▀▀  █ ▀▄█   █  [/]"
    t3 = "[#CD7F32]█  █ █▄▄▄ █  █ █   █ █▄▄▄ ▀▄▄▀     █  █ ▀▄▄▀ █▄▄▄ █   █   █ [/]"
    c1 = "[#FFD700]⠠⠶⢾⣿⣿⡷⠶⠄[/] [#FFD700]⡠⢄[/]"
    c2 = "[#FFBF00]⠀⠀⠈⣿⣿⠁⠀⠀[/] [#FFBF00]⣿⣿[/]"
    c3 = "[#CD7F32]⠀⠀⠀⠾⠷⠀⠀⠀[/] [#CD7F32]⠇⠸[/]"
    if enable_links:
        v1 = "[link=https://www.ankh.md]Ankh.md (__ANKH_VERSION__)[/link]"
        v2 = "[link=__HERMES_GITHUB_URL__]Hermes (__HERMES_VERSION__)[/link]"
    else:
        v1 = "Ankh.md (__ANKH_VERSION__)"
        v2 = "Hermes (__HERMES_VERSION__)"
    v3 = ""
    vers_w = max(len("Ankh.md (" + "__ANKH_VERSION__" + ")"), len("Hermes (" + "__HERMES_VERSION__" + ")"), 5, 10)
    v1_padded = " " * (vers_w - len("Ankh.md (" + "__ANKH_VERSION__" + ")")) + v1
    v2_padded = " " * (vers_w - len("Hermes (" + "__HERMES_VERSION__" + ")")) + v2
    v3_padded = " " * (vers_w) + v3
    w = shutil.get_terminal_size().columns
    gap = "   "
    right_block_w = vers_w + len(gap) + 11
    pad1 = max(0, w - 61 - right_block_w)
    pad2 = max(0, w - 60 - right_block_w)
    return "\\n".join([
        t1 + " " * pad1 + f"[#8B8682]{v1_padded}[/]" + gap + c1,
        t2 + " " * pad1 + f"[#8B8682]{v2_padded}[/]" + gap + c2,
        t3 + " " * pad2 + f"[#8B8682]{v3_padded}[/]" + gap + c3,
    ])'''


def _get_vendor_version() -> str:
    """Read source.version from vendor.json (source of truth for Hermes version)."""
    try:
        pkg_root = Path(__file__).resolve().parent.parent.parent.parent
        vendor = pkg_root / "src" / "vendor.json"
        if vendor.exists():
            data = json.loads(vendor.read_text(encoding="utf-8"))
            return str(data.get("source", {}).get("version", "?"))
    except Exception:
        pass
    return "?"


def _get_ankh_version() -> str:
    """Read package.json version (no v prefix)."""
    try:
        pkg_root = Path(__file__).resolve().parent.parent.parent.parent
        pkg = pkg_root / "package.json"
        if pkg.exists():
            data = json.loads(pkg.read_text(encoding="utf-8"))
            return str(data.get("version", "?")).lstrip("v")
    except Exception:
        pass
    return "?"


def _get_hermes_github_url() -> str:
    """GitHub tree URL for the exact Hermes version we pulled."""
    try:
        pkg_root = Path(__file__).resolve().parent.parent.parent.parent
        vendor = pkg_root / "src" / "vendor.json"
        if vendor.exists():
            data = json.loads(vendor.read_text(encoding="utf-8"))
            src = data.get("source", {})
            url = src.get("url", "").rstrip("/")
            version = src.get("version", "")
            if url and version:
                return f"{url}/tree/{version}"
    except Exception:
        pass
    return "https://github.com/NousResearch/hermes-agent"


def _new_ankh_banner_build() -> str:
    hermes_ver = _get_vendor_version().lstrip("v")
    ankh_ver = _get_ankh_version()
    hermes_url = _get_hermes_github_url()
    return (
        NEW_ANKH_BANNER_BUILD_TEMPLATE.replace("__HERMES_VERSION__", hermes_ver)
        .replace("__ANKH_VERSION__", ankh_ver)
        .replace("__HERMES_GITHUB_URL__", hermes_url)
    )


def _new_logo() -> str:
    return _new_ankh_banner_build() + '''

HERMES_AGENT_LOGO_ANKH = None  # unused; _build_ankh_banner() used instead'''

OLD_LEFT = '    left_lines = ["", HERMES_CADUCEUS, ""]'
NEW_LEFT = '''    if ankh_mode:
        left_lines = [""]
    else:
        left_lines = ["", HERMES_CADUCEUS, ""]'''

# cli.py uses _hero instead of HERMES_CADUCEUS; skip caduceus in Ankh mode
OLD_LEFT_CLI = '''    _hero = _bskin.banner_hero if hasattr(_bskin, 'banner_hero') and _bskin.banner_hero else HERMES_CADUCEUS
    left_lines = ["", _hero, ""]'''
NEW_LEFT_CLI = '''    _hero = _bskin.banner_hero if hasattr(_bskin, 'banner_hero') and _bskin.banner_hero else HERMES_CADUCEUS
    if ankh_mode:
        left_lines = [""]
    else:
        left_lines = ["", _hero, ""]'''

# banner.py needs ankh_mode before the if block; cli.py has it from banner patch
OLD_ANKH_BANNER = '    tools = tools or []\n    enabled_toolsets = enabled_toolsets or []\n\n    _, unavailable_toolsets'
NEW_ANKH_BANNER = '    tools = tools or []\n    enabled_toolsets = enabled_toolsets or []\n    ankh_mode = bool(_ankh_suffix())\n\n    _, unavailable_toolsets'

OLD_LAYOUT = '''    right_content = "\\n".join(right_lines)
    layout_table.add_row(left_content, right_content)'''

NEW_LAYOUT = '''    right_content = "\\n".join(right_lines)
    if ankh_mode:
        term_width = shutil.get_terminal_size().columns
        layout_table = Table.grid(padding=(0, 2))
        layout_table.add_column("main", justify="left")
        model_content = "\\n".join(left_lines[1:])
        try:
            skills_idx = next(i for i, l in enumerate(right_lines) if l == "[bold #FFBF00]Skills[/]")
        except StopIteration:
            skills_idx = len(right_lines) - 1
        tools_content = "\\n".join(right_lines[:skills_idx + 1])
        def _fmt_skill(cat, names):
            n = ", ".join(f"[#FFF8DC]{x}[/]" for x in names[:4])
            if len(names) > 4:
                n += ", [dim]...[/]"
            return f"[#CD7F32]{cat}:[/] {n}"
        skills_items = sorted(skills_by_category.items())
        if term_width >= 80:
            skills_grid = Table.grid(padding=(0, 3))
            skills_grid.add_column("left", justify="left", min_width=38)
            skills_grid.add_column("right", justify="left", min_width=38)
            for i in range(0, len(skills_items), 2):
                left = _fmt_skill(*skills_items[i])
                right = _fmt_skill(*skills_items[i + 1]) if i + 1 < len(skills_items) else ""
                skills_grid.add_row(left, right)
            skills_content = skills_grid
        else:
            skills_lines = [_fmt_skill(c, n) for c, n in skills_items]
            skills_content = "\\n".join(skills_lines)
        summary = right_lines[-1]
        full = Table.grid(padding=(0, 0))
        full.add_column("main", justify="left")
        full.add_row(model_content)
        full.add_row("")
        full.add_row(tools_content)
        full.add_row("")
        full.add_row(skills_content)
        full.add_row("")
        full.add_row(summary)
        layout_table.add_row(full)
    else:
        layout_table.add_row(left_content, right_content)'''

# Match the ankh block that banner.patch adds to cli.py
# build_welcome_banner signature: add enable_links for ChatConsole (avoids OSC 8 corruption)
OLD_BANNER_SIGNATURE = "def build_welcome_banner(console: Console, model: str, cwd: str, tools: List[dict] = None, enabled_toolsets: List[str] = None, session_id: str = None, context_length: int = None):"
NEW_BANNER_SIGNATURE = "def build_welcome_banner(console: Console, model: str, cwd: str, tools: List[dict] = None, enabled_toolsets: List[str] = None, session_id: str = None, context_length: int = None, enable_links: bool = True):"

OLD_LAYOUT_CLI_BLOCK = '''    right_content = "\\n".join(right_lines)
    
    # Add to table (single-col in Ankh mode)
    if ankh_mode:
        term_width = shutil.get_terminal_size().columns
        layout_table = Table.grid(padding=(0, 2))
        layout_table.add_column("main", justify="left")
        model_content = "\\n".join(left_lines[1:])
        try:
            skills_idx = next(i for i, line in enumerate(right_lines) if line == f"[bold {_accent}]Skills[/]")
        except StopIteration:
            skills_idx = len(right_lines) - 1
        tools_content = "\\n".join(right_lines[:skills_idx + 1])

        def _fmt_skill(cat, names):
            rendered = ", ".join(f"[{_text}]{name}[/]" for name in names[:4])
            if len(names) > 4:
                rendered += ", [dim]...[/]"
            return f"[dim {_dim}]{cat}:[/] {rendered}"

        skills_items = sorted(skills_by_category.items())
        if term_width >= 80:
            skills_grid = Table.grid(padding=(0, 3))
            skills_grid.add_column("left", justify="left", min_width=38)
            skills_grid.add_column("right", justify="left", min_width=38)
            for i in range(0, len(skills_items), 2):
                left = _fmt_skill(*skills_items[i])
                right = _fmt_skill(*skills_items[i + 1]) if i + 1 < len(skills_items) else ""
                skills_grid.add_row(left, right)
            skills_content = skills_grid
        else:
            skills_content = "\\n".join(_fmt_skill(category, names) for category, names in skills_items)

        summary = right_lines[-1]
        full = Table.grid(padding=(0, 0))
        full.add_column("main", justify="left")
        full.add_row(model_content)
        full.add_row("")
        full.add_row(tools_content)
        full.add_row("")
        full.add_row(skills_content)
        full.add_row("")
        full.add_row(summary)
        layout_table.add_row(full)
    else:
        layout_table.add_row(left_content, right_content)'''

OLD_SAVE_CONFIG = '''    Respects the same lookup order as load_cli_config():
    1. ~/.hermes/config.yaml (user config - preferred, used if it exists)
    2. ./cli-config.yaml (project config - fallback)
    
    Args:
        key_path: Dot-separated path like "agent.system_prompt"
        value: Value to save
    
    Returns:
        True if successful, False otherwise
    """
    # Use the same precedence as load_cli_config: user config first, then project config
    user_config_path = Path.home() / '.hermes' / 'config.yaml'
    project_config_path = Path(__file__).parent / 'cli-config.yaml'
    config_path = user_config_path if user_config_path.exists() else project_config_path
    
    try:'''

NEW_SAVE_CONFIG = '''    Uses scope-aware config path (get_config_path): when inside a valid .agent
    project, writes to .agent/config.yaml; otherwise ~/.hermes/config.yaml.
    Matches load_cli_config() merge order so /prompt and /personality persist
    to the correct overlay file.
    
    Args:
        key_path: Dot-separated path like "agent.system_prompt"
        value: Value to save
    
    Returns:
        True if successful, False otherwise
    """
    try:
        from hermes_cli.config import get_config_path
        config_path = get_config_path()
    except Exception:
        user_config_path = Path.home() / '.hermes' / 'config.yaml'
        project_config_path = Path(__file__).parent / 'cli-config.yaml'
        config_path = user_config_path if user_config_path.exists() else project_config_path
    
    try:'''

# Custom box: Mainframe, Model, Path (plain text), Session, Active, Hint - no links
# Matches cache state for replacement to version with links
OLD_LAYOUT_CLI_BLOCK_PLAIN = '''    right_content = "\\n".join(right_lines)
    
    # Add to table (single-col in Ankh mode)
    if ankh_mode:
        from hermes_cli.config import get_agent_identity
        _, agent_title = get_agent_identity()
        mainframe = "Hermes Agent (Nous Research)"
        model_short = model.split("/")[-1] if "/" in model else model
        if len(model_short) > 28:
            model_short = model_short[:25] + "..."
        cwd_resolved = Path(cwd).resolve()
        path_str = str(cwd_resolved)
        path_display = path_str if len(path_str) <= 45 else "…/" + cwd_resolved.name
        session_display = (session_id[:8] + "…" + session_id[-4:]) if session_id and len(session_id) > 12 else (session_id or "")
        total_skills = sum(len(s) for s in skills_by_category.values())
        has_custom = False
        try:
            from hermes_cli.config import get_agent_prompt
            has_custom = bool(get_agent_prompt())
        except Exception:
            pass
        active_parts = [f"{len(tools)} Tools", f"{total_skills} Skills"]
        if has_custom:
            active_parts.append("Instructions")
        active_line = " · ".join(active_parts)
        lines = [
            "",
            f"[bold {_accent}]Mainframe[/]: [{_text}]{mainframe}[/]",
            f"[bold {_accent}]Model[/]: [{_text}]{model_short}[/]",
            f"[bold {_accent}]Path[/]: [{_text}]{path_display}[/]",
        ]
        if session_display:
            lines.append(f"[bold {_accent}]Session[/]: [{_text}]{session_display}[/]")
        lines.extend([
            f"[bold {_accent}]Active[/]: [{_text}]{active_line}[/]",
            "",
            f"[{_dim}]Hint: Type /help for commands.[/]",
        ])
        full = Table.grid(padding=(0, 0))
        full.add_column("main", justify="left")
        full.add_row("\\n".join(lines))
        layout_table = Table.grid(padding=(0, 2))
        layout_table.add_column("main", justify="left")
        layout_table.add_row(full)
    else:
        layout_table.add_row(left_content, right_content)'''

# Custom box: Mainframe, Model, Path (path_link only), Session, Active, Hint
# Matches cache state with path_link for replacement to full links
OLD_LAYOUT_CLI_BLOCK_WITH_LINK = '''    right_content = "\\n".join(right_lines)
    
    # Add to table (single-col in Ankh mode)
    if ankh_mode:
        from hermes_cli.config import get_agent_identity
        _, agent_title = get_agent_identity()
        mainframe = "Hermes Agent (Nous Research)"
        model_short = model.split("/")[-1] if "/" in model else model
        if len(model_short) > 28:
            model_short = model_short[:25] + "..."
        cwd_resolved = Path(cwd).resolve()
        path_uri = cwd_resolved.as_uri()
        path_str = str(cwd_resolved)
        path_display = path_str if len(path_str) <= 45 else "…/" + cwd_resolved.name
        path_link = f"[link={path_uri}]{path_display}[/link]"
        session_display = (session_id[:8] + "…" + session_id[-4:]) if session_id and len(session_id) > 12 else (session_id or "")
        total_skills = sum(len(s) for s in skills_by_category.values())
        has_custom = False
        try:
            from hermes_cli.config import get_agent_prompt
            has_custom = bool(get_agent_prompt())
        except Exception:
            pass
        active_parts = [f"{len(tools)} Tools", f"{total_skills} Skills"]
        if has_custom:
            active_parts.append("Instructions")
        active_line = " · ".join(active_parts)
        lines = [
            f"[bold {_accent}]Mainframe[/]: [{_text}]{mainframe}[/]",
            f"[bold {_accent}]Model[/]: [{_text}]{model_short}[/]",
            f"[bold {_accent}]Path[/]: {path_link}",
        ]
        if session_display:
            lines.append(f"[bold {_accent}]Session[/]: [{_text}]{session_display}[/]")
        lines.extend([
            f"[bold {_accent}]Active[/]: [{_text}]{active_line}[/]",
            "",
            f"[{_dim}]Welcome to Hermes Agent! Type your message or /help for commands.[/]",
        ])
        full = Table.grid(padding=(0, 0))
        full.add_column("main", justify="left")
        full.add_row("\\n".join(lines))
        layout_table = Table.grid(padding=(0, 2))
        layout_table.add_column("main", justify="left")
        layout_table.add_row(full)
    else:
        layout_table.add_row(left_content, right_content)'''

NEW_LAYOUT_CLI_BLOCK = '''    right_content = "\\n".join(right_lines)
    
    # Add to table (single-col in Ankh mode)
    if ankh_mode:
        from hermes_cli.config import get_agent_identity
        _, agent_title = get_agent_identity()
        CONFIG_URL = "https://hermes-agent.nousresearch.com/docs/user-guide/configuration#inference-providers"
        SESSIONS_URL = "https://hermes-agent.nousresearch.com/docs/user-guide/sessions"
        DOCS_URL = "https://hermes-agent.nousresearch.com/docs/"
        mainframe = "Hermes Agent (Nous Research)"
        model_short = model.split("/")[-1] if "/" in model else model
        if len(model_short) > 28:
            model_short = model_short[:25] + "..."
        cwd_resolved = Path(cwd).resolve()
        path_uri = cwd_resolved.as_uri()
        path_str = str(cwd_resolved)
        path_display = path_str if len(path_str) <= 45 else "…/" + cwd_resolved.name
        path_link = f"[link={path_uri}]{path_display}[/link]"
        model_link = f"[link={CONFIG_URL}]{model_short}[/link]"
        mainframe_link = f"[link={DOCS_URL}]{mainframe}[/link]"
        session_display = session_id or ""
        session_link = f"[link={SESSIONS_URL}]{session_display}[/link]" if session_display else ""
        if enable_links:
            mainframe_val = mainframe_link
            model_val = model_link
            path_val = path_link
            session_val = session_link if session_display else ""
        else:
            mainframe_val = f"[{_text}]{mainframe}[/]"
            model_val = f"[{_text}]{model_short}[/]"
            path_val = f"[{_text}]{path_display}[/]"
            session_val = f"[{_text}]{session_display}[/]" if session_display else ""
        total_skills = sum(len(s) for s in skills_by_category.values())
        has_custom = False
        try:
            from hermes_cli.config import get_agent_prompt
            has_custom = bool(get_agent_prompt())
        except Exception:
            pass
        active_parts = [f"{len(tools)} Tools", f"{total_skills} Skills"]
        if has_custom:
            active_parts.append("Instructions")
        active_line = " · ".join(active_parts)
        lines = [
            "",
            f"[bold {_accent}]Mainframe[/]: {mainframe_val}",
            f"[bold {_accent}]Model[/]: {model_val}",
            f"[bold {_accent}]Path[/]: {path_val}",
        ]
        if session_display:
            lines.append(f"[bold {_accent}]Session[/]: {session_val}")
        lines.extend([
            f"[bold {_accent}]Active[/]: [{_text}]{active_line}[/]",
            "",
            f"[{_dim}]Welcome to Hermes Agent! Type your message or /help for commands.[/]",
        ])
        full = Table.grid(padding=(0, 0))
        full.add_column("main", justify="left")
        full.add_row("\\n".join(lines))
        layout_table = Table.grid(padding=(0, 2))
        layout_table.add_column("main", justify="left")
        layout_table.add_row(full)
    else:
        layout_table.add_row(left_content, right_content)'''

# Cache state: has links but no enable_links conditional (upgrade to conditional)
OLD_LAYOUT_CLI_BLOCK_LINKS_NO_ENABLE = '''    right_content = "\\n".join(right_lines)
    
    # Add to table (single-col in Ankh mode)
    if ankh_mode:
        from hermes_cli.config import get_agent_identity
        _, agent_title = get_agent_identity()
        CONFIG_URL = "https://hermes-agent.nousresearch.com/docs/user-guide/configuration#inference-providers"
        SESSIONS_URL = "https://hermes-agent.nousresearch.com/docs/user-guide/sessions"
        DOCS_URL = "https://hermes-agent.nousresearch.com/docs/"
        mainframe = "Hermes Agent (Nous Research)"
        model_short = model.split("/")[-1] if "/" in model else model
        if len(model_short) > 28:
            model_short = model_short[:25] + "..."
        cwd_resolved = Path(cwd).resolve()
        path_uri = cwd_resolved.as_uri()
        path_str = str(cwd_resolved)
        path_display = path_str if len(path_str) <= 45 else "…/" + cwd_resolved.name
        path_link = f"[link={path_uri}]{path_display}[/link]"
        model_link = f"[link={CONFIG_URL}]{model_short}[/link]"
        mainframe_link = f"[link={DOCS_URL}]{mainframe}[/link]"
        session_display = session_id or ""
        session_link = f"[link={SESSIONS_URL}]{session_display}[/link]" if session_display else ""
        total_skills = sum(len(s) for s in skills_by_category.values())
        has_custom = False
        try:
            from hermes_cli.config import get_agent_prompt
            has_custom = bool(get_agent_prompt())
        except Exception:
            pass
        active_parts = [f"{len(tools)} Tools", f"{total_skills} Skills"]
        if has_custom:
            active_parts.append("Instructions")
        active_line = " · ".join(active_parts)
        lines = [
            "",
            f"[bold {_accent}]Mainframe[/]: {mainframe_link}",
            f"[bold {_accent}]Model[/]: {model_link}",
            f"[bold {_accent}]Path[/]: {path_link}",
        ]
        if session_display:
            lines.append(f"[bold {_accent}]Session[/]: {session_link}")
        lines.extend([
            f"[bold {_accent}]Active[/]: [{_text}]{active_line}[/]",
            "",
            f"[{_dim}]Welcome to Hermes Agent! Type your message or /help for commands.[/]",
        ])
        full = Table.grid(padding=(0, 0))
        full.add_column("main", justify="left")
        full.add_row("\\n".join(lines))
        layout_table = Table.grid(padding=(0, 2))
        layout_table.add_column("main", justify="left")
        layout_table.add_row(full)
    else:
        layout_table.add_row(left_content, right_content)'''

NEW_LAYOUT_CLI = NEW_LAYOUT.replace(
    '    right_content = "\\n".join(right_lines)\n    if ankh_mode:',
    '    right_content = "\\n".join(right_lines)\n    \n    # Add to table (single-col in Ankh mode)\n    if ankh_mode:'
)

# /clear handler: ChatConsole + enable_links=False avoids OSC 8 corruption
OLD_CLEAR_SYS_STDOUT = """            # Show fresh banner.  Use sys.__stdout__ so Rich output (including OSC 8
            # links) reaches terminal unchanged.  patch_stdout replaces sys.stdout;
            # sys.__stdout__ bypasses it, matching first-load behavior.
            if self._app:
                _direct_console = Console(file=sys.__stdout__, force_terminal=True, highlight=False)
                term_w = shutil.get_terminal_size().columns
                _direct_console.width = term_w
                if self.compact or term_w < 80:
                    _direct_console.print(_build_compact_banner())
                else:
                    tools = get_tool_definitions(enabled_toolsets=self.enabled_toolsets, quiet_mode=True)
                    cwd = os.getenv("TERMINAL_CWD", os.getcwd())
                    ctx_len = None
                    if hasattr(self, 'agent') and self.agent and hasattr(self.agent, 'context_compressor'):
                        ctx_len = self.agent.context_compressor.context_length
                    build_welcome_banner(
                        console=_direct_console,
                        model=self.model,
                        cwd=cwd,
                        tools=tools,
                        enabled_toolsets=self.enabled_toolsets,
                        session_id=self.session_id,
                        context_length=ctx_len,
                    )
                print("  ✨ (◕‿◕)✨ Fresh start! Screen cleared and conversation reset.\\n", flush=True)"""
OLD_CLEAR_BANNER_BLOCK = """            # Show fresh banner.  Inside the TUI we must route Rich output
            # through ChatConsole (which uses prompt_toolkit's native ANSI
            # renderer) instead of self.console (which writes raw to stdout
            # and gets mangled by patch_stdout).
            if self._app:
                cc = ChatConsole()
                term_w = shutil.get_terminal_size().columns
                if self.compact or term_w < 80:
                    cc.print(_build_compact_banner())
                else:
                    tools = get_tool_definitions(enabled_toolsets=self.enabled_toolsets, quiet_mode=True)
                    cwd = os.getenv("TERMINAL_CWD", os.getcwd())
                    ctx_len = None
                    if hasattr(self, 'agent') and self.agent and hasattr(self.agent, 'context_compressor'):
                        ctx_len = self.agent.context_compressor.context_length
                    build_welcome_banner(
                        console=cc,
                        model=self.model,
                        cwd=cwd,
                        tools=tools,
                        enabled_toolsets=self.enabled_toolsets,
                        session_id=self.session_id,
                        context_length=ctx_len,
                        enable_links=False,
                    )
                _cprint("  ✨ (◕‿◕)✨ Fresh start! Screen cleared and conversation reset.\\n")"""
# Fresh cache (from banner.patch): no enable_links in build_welcome_banner call
OLD_CLEAR_BANNER_BLOCK_NO_ENABLE = OLD_CLEAR_BANNER_BLOCK.replace(
    "                        enable_links=False,\n                    )",
    "                    )",
)
# ChatConsole + enable_links=False avoids OSC 8 corruption in both top logo and box
NEW_CLEAR_BANNER_BLOCK = """            # Show fresh banner.  Inside the TUI we must route Rich output
            # through ChatConsole (which uses prompt_toolkit's native ANSI
            # renderer) instead of self.console (which writes raw to stdout
            # and gets mangled by patch_stdout).  enable_links=False avoids OSC 8
            # corruption in both top logo and info box.
            if self._app:
                cc = ChatConsole()
                term_w = shutil.get_terminal_size().columns
                if self.compact or term_w < 80:
                    cc.print(_build_compact_banner())
                else:
                    tools = get_tool_definitions(enabled_toolsets=self.enabled_toolsets, quiet_mode=True)
                    cwd = os.getenv("TERMINAL_CWD", os.getcwd())
                    ctx_len = None
                    if hasattr(self, 'agent') and self.agent and hasattr(self.agent, 'context_compressor'):
                        ctx_len = self.agent.context_compressor.context_length
                    build_welcome_banner(
                        console=cc,
                        model=self.model,
                        cwd=cwd,
                        tools=tools,
                        enabled_toolsets=self.enabled_toolsets,
                        session_id=self.session_id,
                        context_length=ctx_len,
                        enable_links=False,
                    )
                _cprint("  ✨ (◕‿◕)✨ Fresh start! Screen cleared and conversation reset.\\n")"""


OLD_PRINT_ANKH = "        console.print(HERMES_AGENT_LOGO_ANKH)"
OLD_PRINT_ANKH_ALT = """        console.print(_build_ankh_banner())
        console.print()"""
NEW_PRINT_ANKH = """        console.print(_build_ankh_banner(enable_links))
        console.print()"""

OLD_RESPONSE_LABEL = '''                try:
                    from hermes_cli.skin_engine import get_active_skin
                    _skin = get_active_skin()
                    label = _skin.get_branding("response_label", "⚕ Hermes")
                    _resp_color = _skin.get_color("response_border", "#CD7F32")
                except Exception:
                    label = "⚕ Hermes"
                    _resp_color = "#CD7F32"

                _chat_console = ChatConsole()'''
NEW_RESPONSE_LABEL = '''                try:
                    from hermes_cli.skin_engine import get_active_skin
                    _skin = get_active_skin()
                    label = _skin.get_branding("response_label", "⚕ Hermes")
                    _resp_color = _skin.get_color("response_border", "#CD7F32")
                except Exception:
                    label = "⚕ Hermes"
                    _resp_color = "#CD7F32"

                try:
                    from hermes_cli.config import get_agent_identity
                    _, agent_title = get_agent_identity()
                    if agent_title:
                        label = f"⚕ {agent_title}"
                except Exception:
                    pass

                _chat_console = ChatConsole()'''

# Response Panel: rounded corners + outside padding (match Hermes styling)
# Two indentation levels: background task (24 spaces) and main response (20 spaces)
OLD_RESPONSE_PANEL_BG = '''                        box=rich_box.HORIZONTALS,
                        padding=(1, 2),
                    ))'''
NEW_RESPONSE_PANEL_BG = '''                        box=rich_box.ROUNDED,
                        padding=(1, 2),
                    ))'''
OLD_RESPONSE_PANEL_MAIN = '''                    box=rich_box.HORIZONTALS,
                    padding=(1, 2),
                ))'''
NEW_RESPONSE_PANEL_MAIN = '''                    box=rich_box.ROUNDED,
                    padding=(1, 2),
                ))'''

# Fallback: cache already has ROUNDED but no title_align
OLD_RESPONSE_PANEL_BG_CACHE = '''                        box=rich_box.ROUNDED,
                        padding=(1, 2),
                    ))'''
OLD_RESPONSE_PANEL_MAIN_CACHE = '''                    box=rich_box.ROUNDED,
                    padding=(1, 2),
                ))'''

# User message display: Panel with "User" title, orange border, full width
OLD_USER_MSG_DISPLAY = '''                    if paste_match:
                        paste_path = Path(paste_match.group(1))
                        if paste_path.exists():
                            full_text = paste_path.read_text(encoding="utf-8")
                            line_count = full_text.count('\\n') + 1
                            print()
                            _cprint(f"{_GOLD}●{_RST} {_BOLD}[Pasted text: {line_count} lines]{_RST}")
                            user_input = full_text
                        else:
                            print()
                            _cprint(f"{_GOLD}●{_RST} {_BOLD}{user_input}{_RST}")
                    else:
                        if '\\n' in user_input:
                            first_line = user_input.split('\\n')[0]
                            line_count = user_input.count('\\n') + 1
                            print()
                            _cprint(f"{_GOLD}●{_RST} {_BOLD}{first_line}{_RST} {_DIM}(+{line_count - 1} lines){_RST}")
                        else:
                            print()
                            _cprint(f"{_GOLD}●{_RST} {_BOLD}{user_input}{_RST}")
'''
NEW_USER_MSG_DISPLAY = '''                    if paste_match:
                        paste_path = Path(paste_match.group(1))
                        if paste_path.exists():
                            full_text = paste_path.read_text(encoding="utf-8")
                            line_count = full_text.count('\\n') + 1
                            display_text = f"[Pasted text: {line_count} lines]"
                            user_input = full_text
                        else:
                            display_text = user_input
                    else:
                        if '\\n' in user_input:
                            first_line = user_input.split('\\n')[0]
                            line_count = user_input.count('\\n') + 1
                            display_text = f"{first_line} (+{line_count - 1} lines)"
                        else:
                            display_text = user_input
                    _user_cc = ChatConsole()
                    _user_cc.print(Panel(
                        display_text,
                        title="[bold]● User[/]",
                        title_align="left",
                        border_style="#CD7F32",
                        box=rich_box.ROUNDED,
                        padding=(1, 2),
                    ))
'''

# Remove yellow divider between user message and agent response (simple timeline)
OLD_CHAT_DIVIDER = '''        self.conversation_history.append({"role": "user", "content": message})
        
        _cprint(f"{_GOLD}{'─' * 40}{_RST}")
        print(flush=True)
        
        try:'''
NEW_CHAT_DIVIDER = '''        self.conversation_history.append({"role": "user", "content": message})
        
        try:'''

# Match banner.patch output (banner.py uses title_color, agent_name, border_color)
OLD_PANEL_TITLE = '''    outer_panel = Panel(
        layout_table,
        title=f"[bold {title_color}]{agent_name} v{VERSION} ({RELEASE_DATE})[/]",
        border_style=border_color,
        padding=(0, 2),
    )'''
NEW_PANEL_TITLE = '''    if ankh_mode:
        from hermes_cli.config import get_agent_identity
        _, _ankh_title = get_agent_identity()
        _panel_title = f"[bold {title_color}]{_ankh_title}[/]" if _ankh_title else f"[bold {title_color}]A Wandering Agent[/]"
    else:
        _panel_title = f"[bold {title_color}]{agent_name} v{VERSION} ({RELEASE_DATE}){_ankh_suffix()}[/]"
    outer_panel = Panel(
        layout_table,
        title=_panel_title,
        border_style=border_color,
        padding=(0, 2),
        title_align="left" if ankh_mode else "center",
    )'''

# cli.py uses _title_c, _agent_name, _border_c and includes _ankh_suffix() in title
OLD_PANEL_TITLE_CLI = '''    outer_panel = Panel(
        layout_table,
        title=f"[bold {_title_c}]{_agent_name} v{VERSION} ({RELEASE_DATE}){_ankh_suffix()}[/]",
        border_style=_border_c,
        padding=(0, 2),
    )'''
NEW_PANEL_TITLE_CLI = '''    if ankh_mode:
        from hermes_cli.config import get_agent_identity
        _, _ankh_title = get_agent_identity()
        _panel_title = f"[bold {_title_c}]{_ankh_title}[/]" if _ankh_title else f"[bold {_title_c}]A Wandering Agent[/]"
    else:
        _panel_title = f"[bold {_title_c}]{_agent_name} v{VERSION} ({RELEASE_DATE}){_ankh_suffix()}[/]"
    outer_panel = Panel(
        layout_table,
        title=_panel_title,
        border_style=_border_c,
        padding=(0, 2),
        title_align="left" if ankh_mode else "center",
    )'''

# Suppress welcome message below agent box in Ankh mode (it's now inside the box)
OLD_WELCOME_PRINT = '''        try:
            from hermes_cli.skin_engine import get_active_skin
            _welcome_skin = get_active_skin()
            _welcome_text = _welcome_skin.get_branding("welcome", "Welcome to Hermes Agent! Type your message or /help for commands.")
            _welcome_color = _welcome_skin.get_color("banner_text", "#FFF8DC")
        except Exception:
            _welcome_text = "Welcome to Hermes Agent! Type your message or /help for commands."
            _welcome_color = "#FFF8DC"
        self.console.print(f"[{_welcome_color}]{_welcome_text}[/]")
        self.console.print()'''

NEW_WELCOME_PRINT = '''        try:
            from hermes_cli.banner import _ankh_suffix
            _ankh_mode = bool(_ankh_suffix())
        except Exception:
            _ankh_mode = False
        if not _ankh_mode:
            try:
                from hermes_cli.skin_engine import get_active_skin
                _welcome_skin = get_active_skin()
                _welcome_text = _welcome_skin.get_branding("welcome", "Welcome to Hermes Agent! Type your message or /help for commands.")
                _welcome_color = _welcome_skin.get_color("banner_text", "#FFF8DC")
            except Exception:
                _welcome_text = "Welcome to Hermes Agent! Type your message or /help for commands."
                _welcome_color = "#FFF8DC"
            self.console.print(f"[{_welcome_color}]{_welcome_text}[/]")
            self.console.print()'''


def apply(path: str) -> bool:
    with open(path, encoding="utf-8") as f:
        s = f.read()
    changed = False
    new_logo = _new_logo()
    new_banner_build = _new_ankh_banner_build()
    if OLD_LOGO in s:
        s = s.replace(OLD_LOGO, new_logo)
        changed = True
    if OLD_ANKH_BANNER_BUILD in s:
        s = s.replace(OLD_ANKH_BANNER_BUILD, new_banner_build)
        changed = True
    # Also replace the compact-only version (from previous apply) with full layout
    OLD_COMPACT = '''def _build_ankh_banner() -> str:
    """Build Ankh banner with compact graphic top-right, no tall ASCII art."""
    import shutil
    c1 = "[#FFD700] ⠤⣿⣿⠤ ⠊⠕  [/]"
    c2 = "[#FFBF00] ⠒⣿⠒  ⠒⣿⠒ [/]"
    c3 = "[#CD7F32] ⠶⠿⠶  ⠶⠿⠶ [/]"
    w = shutil.get_terminal_size().columns
    # Right-align graphic (~20 chars wide)
    pad = max(0, w - 20)
    return "\\n".join([
        " " * pad + c1,
        " " * pad + c2,
        " " * pad + c3,
    ])'''
    if OLD_COMPACT in s:
        s = s.replace(OLD_COMPACT, new_banner_build)
        changed = True
    # Match previous format: Hermes 2026.3.12, 2026.3.12, [Ankh.md](https://www.ankh.md)
    OLD_CACHE_ANKH_MD_LINK = '''def _build_ankh_banner() -> str:
    """Build Ankh banner with HERMES AGENT left, versions, ankh/scepter far-right."""
    import shutil
    t1 = "[bold #FFD700]█  █ █▀▀▀ █▀▀▄ █▄ ▄█ █▀▀▀ ▄▀▀▀     ▄▀▀▄ ▄▀▀▀ █▀▀▀ █▄  █ ▀▀█▀▀[/]"
    t2 = "[#FFBF00]█▀▀█ █▀▀  █▀█  █ ▀ █ █▀▀   ▀▀▄     █▀▀█ █ ▀█ █▀▀  █ ▀▄█   █  [/]"
    t3 = "[#CD7F32]█  █ █▄▄▄ █  █ █   █ █▄▄▄ ▀▄▄▀     █  █ ▀▄▄▀ █▄▄▄ █   █   █ [/]"
    c1 = "[#FFD700]⠠⠶⢾⣿⣿⡷⠶⠄[/] [#FFD700]⡠⢄[/]"
    c2 = "[#FFBF00]⠀⠀⠈⣿⣿⠁⠀⠀[/] [#FFBF00]⣿⣿[/]"
    c3 = "[#CD7F32]⠀⠀⠀⠾⠷⠀⠀⠀[/] [#CD7F32]⠇⠸[/]"
    v1 = "Hermes 2026.3.12"
    v2 = "2026.3.12"
    v3 = "[Ankh.md](https://www.ankh.md)"
    vers_w = max(len(v1), len(v2), 7, 10)
    v3_padded = " " * (vers_w - 7) + v3
    w = shutil.get_terminal_size().columns
    gap = "   "
    right_block_w = vers_w + len(gap) + 11
    pad1 = max(0, w - 61 - right_block_w)
    pad2 = max(0, w - 60 - right_block_w)
    return "\\n".join([
        t1 + " " * pad1 + f"[#8B8682]{v1.rjust(vers_w)}[/]" + gap + c1,
        t2 + " " * pad1 + f"[#8B8682]{v2.rjust(vers_w)}[/]" + gap + c2,
        t3 + " " * pad2 + f"[#8B8682]{v3_padded}[/]" + gap + c3,
    ])'''
    if OLD_CACHE_ANKH_MD_LINK in s:
        s = s.replace(OLD_CACHE_ANKH_MD_LINK, new_banner_build)
        changed = True
    # Match current cache: same c1/c2/c3 as NEW, v1 with v prefix, [dim #8B8682]
    OLD_CACHE_VERSIONS_BANNER_CURRENT = '''def _build_ankh_banner() -> str:
    """Build Ankh banner with HERMES AGENT left, versions, ankh/scepter far-right."""
    import shutil
    t1 = "[bold #FFD700]█  █ █▀▀▀ █▀▀▄ █▄ ▄█ █▀▀▀ ▄▀▀▀     ▄▀▀▄ ▄▀▀▀ █▀▀▀ █▄  █ ▀▀█▀▀[/]"
    t2 = "[#FFBF00]█▀▀█ █▀▀  █▀█  █ ▀ █ █▀▀   ▀▀▄     █▀▀█ █ ▀█ █▀▀  █ ▀▄█   █  [/]"
    t3 = "[#CD7F32]█  █ █▄▄▄ █  █ █   █ █▄▄▄ ▀▄▄▀     █  █ ▀▄▄▀ █▄▄▄ █   █   █ [/]"
    c1 = "[#FFD700]⠠⠶⢾⣿⣿⡷⠶⠄[/] [#FFD700]⡠⢄[/]"
    c2 = "[#FFBF00]⠀⠀⠈⣿⣿⠁⠀⠀[/] [#FFBF00]⣿⣿[/]"
    c3 = "[#CD7F32]⠀⠀⠀⠾⠷⠀⠀⠀[/] [#CD7F32]⠇⠸[/]"
    v1 = f"v{VERSION}" if not str(VERSION).startswith("v") else str(VERSION)
    v2 = str(RELEASE_DATE)
    v3 = "Ankh 1.0.0"
    vers_w = max(len(v1), len(v2), len(v3), 10)
    w = shutil.get_terminal_size().columns
    gap = "   "
    right_block_w = vers_w + len(gap) + 11
    pad1 = max(0, w - 61 - right_block_w)
    pad2 = max(0, w - 60 - right_block_w)
    return "\\n".join([
        t1 + " " * pad1 + f"[dim #8B8682]{v1.rjust(vers_w)}[/]" + gap + c1,
        t2 + " " * pad1 + f"[dim #8B8682]{v2.rjust(vers_w)}[/]" + gap + c2,
        t3 + " " * pad2 + f"[dim #8B8682]{v3.rjust(vers_w)}[/]" + gap + c3,
    ])'''
    if OLD_CACHE_VERSIONS_BANNER_CURRENT in s:
        s = s.replace(OLD_CACHE_VERSIONS_BANNER_CURRENT, new_banner_build)
        changed = True
    # Also replace cache state: versions + compact c1 (from prior apply)
    OLD_CACHE_VERSIONS_BANNER = '''def _build_ankh_banner() -> str:
    """Build Ankh banner with HERMES AGENT left, versions right-aligned left of symbol."""
    import shutil
    t1 = "[bold #FFD700]█  █ █▀▀▀ █▀▀▄ █▄ ▄█ █▀▀▀ ▄▀▀▀     ▄▀▀▄ ▄▀▀▀ █▀▀▀ █▄  █ ▀▀█▀▀[/]"
    t2 = "[#FFBF00]█▀▀█ █▀▀  █▀█  █ ▀ █ █▀▀   ▀▀▄     █▀▀█ █ ▀█ █▀▀  █ ▀▄█   █  [/]"
    t3 = "[#CD7F32]█  █ █▄▄▄ █  █ █   █ █▄▄▄ ▀▄▄▀     █  █ ▀▄▄▀ █▄▄▄ █   █   █ [/]"
    v1 = f"v{VERSION}" if not str(VERSION).startswith("v") else str(VERSION)
    v2 = str(RELEASE_DATE)
    v3 = "Ankh 1.0.0"
    vers_w = max(len(v1), len(v2), len(v3), 10)
    c1 = "[#FFD700] ⠤⣿⣿⠤ ⠊⠕  [/]"
    c2 = "[#FFBF00] ⠒⣿⠒  ⠒⣿⠒ [/]"
    c3 = "[#CD7F32] ⠶⠿⠶  ⠶⠿⠶ [/]"
    w = shutil.get_terminal_size().columns
    pad1 = max(0, w - 61 - 11)
    pad2 = max(0, w - 60 - 11)
    return "\\n".join([
        t1 + " " * pad1 + f"[dim #8B8682]{v1.rjust(vers_w)}[/]" + " " + c1,
        t2 + " " * pad1 + f"[dim #8B8682]{v2.rjust(vers_w)}[/]" + " " + c2,
        t3 + " " * pad2 + f"[dim #8B8682]{v3.rjust(vers_w)}[/]" + " " + c3,
    ])'''
    if OLD_CACHE_VERSIONS_BANNER in s:
        s = s.replace(OLD_CACHE_VERSIONS_BANNER, new_banner_build)
        changed = True
    # Also replace previous apply's HERMES AGENT banner with agent title + versions
    OLD_HERMES_AGENT_BANNER = '''def _build_ankh_banner() -> str:
    """Build Ankh banner with HERMES AGENT text left, user graphic far-right."""
    import shutil
    t1 = "[bold #FFD700]█  █ █▀▀▀ █▀▀▄ █▄ ▄█ █▀▀▀ ▄▀▀▀     ▄▀▀▄ ▄▀▀▀ █▀▀▀ █▄  █ ▀▀█▀▀[/]"
    t2 = "[#FFBF00]█▀▀█ █▀▀  █▀█  █ ▀ █ █▀▀   ▀▀▄     █▀▀█ █ ▀█ █▀▀  █ ▀▄█   █  [/]"
    t3 = "[#CD7F32]█  █ █▄▄▄ █  █ █   █ █▄▄▄ ▀▄▄▀     █  █ ▀▄▄▀ █▄▄▄ █   █   █ [/]"
    c1 = "[#FFD700] ⠤⣿⣿⠤ ⠊⠕  [/]"
    c2 = "[#FFBF00] ⠒⣿⠒  ⠒⣿⠒ [/]"
    c3 = "[#CD7F32] ⠶⠿⠶  ⠶⠿⠶ [/]"
    w = shutil.get_terminal_size().columns
    pad1 = max(0, w - 61 - 11)
    pad2 = max(0, w - 60 - 11)
    return "\\n".join([
        t1 + " " * pad1 + c1,
        t2 + " " * pad1 + c2,
        t3 + " " * pad2 + c3,
    ])'''
    if OLD_HERMES_AGENT_BANNER in s:
        s = s.replace(OLD_HERMES_AGENT_BANNER, new_banner_build)
        changed = True
    # Idempotent re-apply: if our output is already there, consider success (vendor.json may have changed)
    if new_banner_build in s:
        changed = True
    if OLD_PRINT_ANKH_ALT in s:
        s = s.replace(OLD_PRINT_ANKH_ALT, NEW_PRINT_ANKH)
        changed = True
    elif OLD_PRINT_ANKH in s:
        s = s.replace(OLD_PRINT_ANKH, NEW_PRINT_ANKH)
        changed = True
    old_panel = OLD_PANEL_TITLE_CLI if path.endswith("cli.py") else OLD_PANEL_TITLE
    new_panel = NEW_PANEL_TITLE_CLI if path.endswith("cli.py") else NEW_PANEL_TITLE
    if old_panel in s:
        s = s.replace(old_panel, new_panel)
        changed = True
    if path.endswith("banner.py") and OLD_ANKH_BANNER in s:
        s = s.replace(OLD_ANKH_BANNER, NEW_ANKH_BANNER)
        changed = True
    # Skip OLD_LEFT for banner.py: banner patch already adds if ankh_mode/else
    if OLD_LEFT in s and not (path.endswith("banner.py") and "if ankh_mode:" in s and "left_lines = [\"\"]" in s):
        s = s.replace(OLD_LEFT, NEW_LEFT)
        changed = True
    if path.endswith("cli.py") and OLD_LEFT_CLI in s:
        s = s.replace(OLD_LEFT_CLI, NEW_LEFT_CLI)
        changed = True
    if path.endswith("cli.py") and OLD_BANNER_SIGNATURE in s:
        s = s.replace(OLD_BANNER_SIGNATURE, NEW_BANNER_SIGNATURE)
        changed = True
    if path.endswith("cli.py"):
        # Match cache with [dim {_dim}] in Hint (Option B: replace with [{_dim}] for transparent bg)
        OLD_LAYOUT_CLI_BLOCK_WITH_DIM = OLD_LAYOUT_CLI_BLOCK_PLAIN.replace(
            'f"[{_dim}]Hint: Type /help for commands.[/]"',
            'f"[dim {_dim}]Hint: Type /help for commands.[/]"'
        )
        OLD_LAYOUT_CLI_BLOCK_WITH_LINK_DIM = OLD_LAYOUT_CLI_BLOCK_WITH_LINK.replace(
            'f"[{_dim}]Hint: Type /help for commands.[/]"', 'f"[dim {_dim}]Hint: Type /help for commands.[/]"'
        )
        # Match cache with full links but truncated session (upgrade to full session ID)
        OLD_LAYOUT_CLI_BLOCK_TRUNCATED_SESSION = NEW_LAYOUT_CLI_BLOCK.replace(
            'session_display = session_id or ""',
            'session_display = (session_id[:8] + "…" + session_id[-4:]) if session_id and len(session_id) > 12 else (session_id or "")'
        )
        # Match cache with Hint instead of Welcome (upgrade to Welcome message)
        OLD_LAYOUT_CLI_BLOCK_WITH_HINT = NEW_LAYOUT_CLI_BLOCK.replace(
            'f"[{_dim}]Welcome to Hermes Agent! Type your message or /help for commands.[/]"',
            'f"[{_dim}]Hint: Type /help for commands.[/]"'
        )
        # Match cache that already has Welcome + empty line (re-apply idempotent)
        OLD_LAYOUT_CLI_BLOCK_WITH_WELCOME = OLD_LAYOUT_CLI_BLOCK.replace(
            'f"[{_dim}]Hint: Type /help for commands.[/]"',
            'f"[{_dim}]Welcome to Hermes Agent! Type your message or /help for commands.[/]"'
        ).replace(
            '        lines = [\n            f"[bold {_accent}]Mainframe[/]',
            '        lines = [\n            "",\n            f"[bold {_accent}]Mainframe[/]'
        )
        if OLD_LAYOUT_CLI_BLOCK_LINKS_NO_ENABLE in s:
            s = s.replace(OLD_LAYOUT_CLI_BLOCK_LINKS_NO_ENABLE, NEW_LAYOUT_CLI_BLOCK)
            changed = True
        elif OLD_LAYOUT_CLI_BLOCK_WITH_HINT in s:
            s = s.replace(OLD_LAYOUT_CLI_BLOCK_WITH_HINT, NEW_LAYOUT_CLI_BLOCK)
            changed = True
        elif OLD_LAYOUT_CLI_BLOCK_TRUNCATED_SESSION in s:
            s = s.replace(OLD_LAYOUT_CLI_BLOCK_TRUNCATED_SESSION, NEW_LAYOUT_CLI_BLOCK)
            changed = True
        elif OLD_LAYOUT_CLI_BLOCK_WITH_WELCOME in s:
            s = s.replace(OLD_LAYOUT_CLI_BLOCK_WITH_WELCOME, NEW_LAYOUT_CLI_BLOCK)
            changed = True
        elif OLD_LAYOUT_CLI_BLOCK_WITH_DIM in s:
            s = s.replace(OLD_LAYOUT_CLI_BLOCK_WITH_DIM, NEW_LAYOUT_CLI_BLOCK)
            changed = True
        elif OLD_LAYOUT_CLI_BLOCK in s:
            s = s.replace(OLD_LAYOUT_CLI_BLOCK, NEW_LAYOUT_CLI_BLOCK)
            changed = True
        elif OLD_LAYOUT_CLI_BLOCK_PLAIN in s:
            s = s.replace(OLD_LAYOUT_CLI_BLOCK_PLAIN, NEW_LAYOUT_CLI_BLOCK)
            changed = True
        elif OLD_LAYOUT_CLI_BLOCK_WITH_LINK_DIM in s:
            s = s.replace(OLD_LAYOUT_CLI_BLOCK_WITH_LINK_DIM, NEW_LAYOUT_CLI_BLOCK)
            changed = True
        elif OLD_LAYOUT_CLI_BLOCK_WITH_LINK in s:
            s = s.replace(OLD_LAYOUT_CLI_BLOCK_WITH_LINK, NEW_LAYOUT_CLI_BLOCK)
            changed = True
        if OLD_CLEAR_SYS_STDOUT in s:
            s = s.replace(OLD_CLEAR_SYS_STDOUT, NEW_CLEAR_BANNER_BLOCK)
            changed = True
        elif OLD_CLEAR_BANNER_BLOCK_NO_ENABLE in s:
            s = s.replace(OLD_CLEAR_BANNER_BLOCK_NO_ENABLE, NEW_CLEAR_BANNER_BLOCK)
            changed = True
        elif OLD_CLEAR_BANNER_BLOCK in s:
            s = s.replace(OLD_CLEAR_BANNER_BLOCK, NEW_CLEAR_BANNER_BLOCK)
            changed = True
    else:
        if OLD_LAYOUT in s:
            s = s.replace(OLD_LAYOUT, NEW_LAYOUT)
            changed = True
    if OLD_SAVE_CONFIG in s:
        s = s.replace(OLD_SAVE_CONFIG, NEW_SAVE_CONFIG)
        changed = True
    if path.endswith("cli.py") and OLD_RESPONSE_LABEL in s:
        s = s.replace(OLD_RESPONSE_LABEL, NEW_RESPONSE_LABEL)
        changed = True
    if path.endswith("cli.py"):
        if OLD_RESPONSE_PANEL_BG in s:
            s = s.replace(OLD_RESPONSE_PANEL_BG, NEW_RESPONSE_PANEL_BG)
            changed = True
        elif OLD_RESPONSE_PANEL_BG_CACHE in s:
            s = s.replace(OLD_RESPONSE_PANEL_BG_CACHE, NEW_RESPONSE_PANEL_BG)
            changed = True
        if OLD_RESPONSE_PANEL_MAIN in s:
            s = s.replace(OLD_RESPONSE_PANEL_MAIN, NEW_RESPONSE_PANEL_MAIN)
            changed = True
        elif OLD_RESPONSE_PANEL_MAIN_CACHE in s:
            s = s.replace(OLD_RESPONSE_PANEL_MAIN_CACHE, NEW_RESPONSE_PANEL_MAIN)
            changed = True
        if OLD_USER_MSG_DISPLAY in s:
            s = s.replace(OLD_USER_MSG_DISPLAY, NEW_USER_MSG_DISPLAY)
            changed = True
        if OLD_CHAT_DIVIDER in s:
            s = s.replace(OLD_CHAT_DIVIDER, NEW_CHAT_DIVIDER)
            changed = True
        if OLD_WELCOME_PRINT in s:
            s = s.replace(OLD_WELCOME_PRINT, NEW_WELCOME_PRINT)
            changed = True
    if changed:
        with open(path, "w", encoding="utf-8") as f:
            f.write(s)
    return changed


def main():
    any_changed = False
    for path in sys.argv[1:]:
        if apply(path):
            print(f"Applied banner_ankh to {path}", file=sys.stderr)
            any_changed = True
    if not any_changed:
        sys.exit(1)


if __name__ == "__main__":
    main()
