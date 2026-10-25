import re
import sys
from pathlib import Path


class CheckError(Exception):
    pass


def component_stem(name):
    path = Path(name)
    if path.is_absolute() or ".." in path.parts:
        raise CheckError(f"invalid ASDF component path: {name}")
    if path.suffix != ".lisp":
        path = Path(f"{name}.lisp")
    return path.with_suffix("").as_posix()


def parse_component_forms(source):
    token_pattern = re.compile(r';[^\n]*|"(?:\\.|[^"\\])*"|[()]|[^\s()]+')
    forms = []
    stack = [forms]
    for match in token_pattern.finditer(source):
        token = match.group(0)
        if token.startswith(";"):
            continue
        if token == "(":
            form = []
            stack[-1].append(form)
            stack.append(form)
        elif token == ")":
            if len(stack) == 1:
                raise CheckError("unbalanced ASDF test components")
            stack.pop()
        elif token.startswith('"'):
            if not token.endswith('"'):
                raise CheckError("unterminated string in ASDF test components")
            stack[-1].append(re.sub(r"\\(.)", r"\1", token[1:-1]))
        else:
            stack[-1].append(token.lower())
    if len(stack) != 1:
        raise CheckError("unbalanced ASDF test components")
    return forms


def component_paths(forms, prefix=()):
    paths = set()
    for form in forms:
        if not isinstance(form, list) or not form:
            continue
        if form[0] == ":module":
            if len(form) < 2 or not isinstance(form[1], str):
                raise CheckError("ASDF module has no string path")
            module = Path(form[1])
            if module.is_absolute() or ".." in module.parts:
                raise CheckError(f"invalid ASDF module path: {form[1]}")
            try:
                components = form[form.index(":components") + 1]
            except (ValueError, IndexError):
                raise CheckError(f"ASDF module has no components: {form[1]}")
            if not isinstance(components, list):
                raise CheckError(f"ASDF module components are not a list: {form[1]}")
            paths.update(component_paths(components, prefix + module.parts))
        elif form[0] in {":file", ":static-file"}:
            if len(form) < 2 or not isinstance(form[1], str):
                raise CheckError(f"ASDF {form[0]} component has no string path")
            paths.add(Path(*prefix, component_stem(form[1])).as_posix())
    return paths


def read_test_system(root):
    asd_path = root / "cl-cc-type.asd"
    source = asd_path.read_text(encoding="utf-8")
    system = re.search(r'(?m)^[ \t]*\(defsystem\s+"cl-cc-type/test"\s', source)
    if system is None:
        raise CheckError('cl-cc-type.asd has no "cl-cc-type/test" system')

    definition = source[system.start() :]
    pathname = re.search(r'(?m)^[ \t]*:pathname[ \t]+"([^"]+)"[ \t]*$', definition)
    components = re.search(r"(?m)^[ \t]*:components[ \t]*$", definition)
    if pathname is None or components is None:
        raise CheckError('test system must define :pathname and :components')

    perform = re.search(r"(?m)^[ \t]*:perform\b", definition[components.end() :])
    if perform is None:
        raise CheckError("test system is missing its :perform boundary")

    component_forms = definition[
        components.end() : components.end() + perform.start()
    ]
    forms = parse_component_forms(component_forms)
    if len(forms) != 1 or not isinstance(forms[0], list):
        raise CheckError("test system has malformed :components")
    names = component_paths(forms[0])
    if not names:
        raise CheckError("test system has no file components")
    if "package" not in names:
        raise CheckError('test system is missing the "package" component')

    return Path(pathname.group(1)), names


def check(root):
    test_path, components = read_test_system(root)
    test_dir = root / test_path
    if not test_dir.is_dir():
        raise CheckError(f"test directory does not exist: {test_dir}")

    disk_files = {
        path.relative_to(test_dir).with_suffix("").as_posix()
        for path in test_dir.rglob("*.lisp")
        if path.is_file()
    }
    test_files = disk_files - {"package"}
    test_components = components - {"package"}
    orphans = sorted(test_files - test_components)
    missing = sorted(components - disk_files)

    print(f"test source files: {len(test_files)}")
    print(f"ASDF test components: {len(test_components)}")
    print(f"orphan test files ({len(orphans)}): {orphans}")
    print(f"ASDF components missing on disk ({len(missing)}): {missing}")

    if not test_files:
        raise CheckError("no test source files found")
    if not test_components:
        raise CheckError("no ASDF test components found")
    if orphans or missing:
        raise CheckError("test files and ASDF :components do not match")


def main(argv):
    if len(argv) > 2:
        print(f"usage: {argv[0]} [repository-root]", file=sys.stderr)
        return 2
    root = Path(argv[1]) if len(argv) == 2 else Path(__file__).resolve().parent.parent
    try:
        check(root.resolve())
    except CheckError as error:
        print(f"check-orphan-tests: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
