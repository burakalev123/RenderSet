#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
toc_file="${repo_root}/RenderSet.toc"

version="$(sed -n 's/^## Version:[[:space:]]*//p' "${toc_file}" | head -n 1)"
if [[ -z "${version}" || ! "${version}" =~ ^[0-9A-Za-z._-]+$ ]]; then
    echo "Could not read a safe version from RenderSet.toc." >&2
    exit 1
fi

package_files=(
    RenderSet.toc
    Core.lua
    Profiles.lua
    Presets.lua
    UI.lua
    Commands.lua
    MinimapButton.lua
    README.md
    CHANGELOG.md
)

for relative_path in "${package_files[@]}"; do
    if [[ ! -f "${repo_root}/${relative_path}" ]]; then
        echo "Missing package file: ${relative_path}" >&2
        exit 1
    fi
done

staging_root="$(mktemp -d "${TMPDIR:-/tmp}/renderset-package.XXXXXX")"
trap 'rm -rf "${staging_root}"' EXIT

package_root="${staging_root}/RenderSet"
mkdir -p "${package_root}"

for relative_path in "${package_files[@]}"; do
    cp "${repo_root}/${relative_path}" "${package_root}/${relative_path}"
done

archive_name="RenderSet-${version}.zip"
(
    cd "${staging_root}"
    zip -q -r "${archive_name}" RenderSet
)

mkdir -p "${repo_root}/dist"
cp "${staging_root}/${archive_name}" "${repo_root}/dist/${archive_name}"

echo "Created dist/${archive_name}"
