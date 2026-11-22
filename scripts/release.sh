#!/usr/bin/env bash
# Prepare a release: bump the changelog and VERSION, test, build, verify,
# commit and tag. The target never pushes.
#
# Usage: APP_NAME="AirBattery" REMOTE=fork scripts/release.sh X.Y.Z
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VERSION="${1:-}"
APP_NAME="${APP_NAME:-AirBattery}"
REMOTE="${REMOTE:-fork}"
VERSION_RE='^[0-9]+\.[0-9]+\.[0-9]+$'
BUMPED=(CHANGELOG.md VERSION)

die() {
	echo "error: $*" >&2
	exit 1
}

[[ -n "$VERSION" ]] || die "usage: scripts/release.sh X.Y.Z"
[[ "$VERSION" =~ $VERSION_RE ]] || die "the version \"$VERSION\" is not a stable X.Y.Z"

# The generated release assets are no reason to refuse a release.
dirty="$(git status --porcelain | grep -vE '^\?\? (AirBattery-.*\.(dmg|dmg\.sha256)|dmgstage/)$' || true)"
[[ -z "$dirty" ]] || {
	printf '%s\n' "$dirty"
	die "the working tree is dirty. Commit or stash your changes first."
}
if git rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null; then
	die "the tag v$VERSION already exists."
fi
git remote get-url "$REMOTE" >/dev/null 2>&1 ||
	die "the remote \"$REMOTE\" is not configured; set REMOTE=<name>."

# The tag must land on the default branch.
branch="$(git symbolic-ref --quiet --short "refs/remotes/$REMOTE/HEAD" 2>/dev/null || true)"
branch="${branch#$REMOTE/}"
if [[ -z "$branch" ]]; then
	for candidate in main master; do
		if git rev-parse -q --verify "refs/remotes/$REMOTE/$candidate" >/dev/null; then
			branch="$candidate"
			break
		fi
	done
fi
[[ -n "$branch" ]] || die "the default branch is unknown; run git fetch $REMOTE first"
git rev-parse -q --verify "refs/remotes/$REMOTE/$branch" >/dev/null ||
	die "$REMOTE/$branch is not in this checkout; run git fetch $REMOTE first"
current="$(git symbolic-ref --quiet --short HEAD || true)"
[[ "$current" == "$branch" ]] ||
	die "the release must be cut from $branch, not ${current:-a detached HEAD}."

# A failure before the commit restores every file, so a stopped release
# leaves no half-bump.
./scripts/changelog.sh bump "$VERSION"
echo "$VERSION" >VERSION

committed=0
restore() {
	local status=$?
	if [[ "$status" -ne 0 && "$committed" -eq 0 ]]; then
		git checkout -- "${BUMPED[@]}" 2>/dev/null || true
		echo "The release bump was restored." >&2
	fi
}
trap restore EXIT

make test
make release-artifacts VERSION="$VERSION"
make verify VERSION="$VERSION"

git add "${BUMPED[@]}"
git commit -m "chore(release): v$VERSION"
committed=1
git tag -a "v$VERSION" -m "$APP_NAME $VERSION"

echo ""
echo "Committed the release bump and tagged v$VERSION. Push it with:"
echo "  git push $REMOTE $branch"
echo "  git push $REMOTE v$VERSION"
