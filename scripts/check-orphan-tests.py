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
    component_forms = "\n".join(
        line for line in component_forms.splitlines()
        if not line.lstrip().startswith(";")
    )
    names = {
        component_stem(match.group(1))
        for match in re.finditer(
            r'\(:file\s+"([^"]+)"(?=[ \t)]|$)', component_forms
        )
    }
    if not names:
        raise CheckError("test system has no :file components")
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
