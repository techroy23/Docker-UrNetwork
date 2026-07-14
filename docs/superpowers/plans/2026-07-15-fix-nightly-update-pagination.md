# Fix Nightly Auto-Update Pagination Plan

**Goal:** Fix `func_check_update` in `start_nightly.sh` to iterate through GitHub releases when the latest release lacks the provider asset (mirroring the fix already applied to `start_update.sh` and `main.yml`).

**Files:**
- `scripts/start_nightly.sh`

**Approach:**
Replace the single `/releases/latest` API call in `func_check_update` with a paginated loop (up to 10 pages, 10 per page) that searches for a release containing `urnetwork-provider-*.tar.gz` in its assets, using `jq` to parse the release array (consistent with `start_update.sh`).

**Changes:**
1. Change `API_URL` from `/releases/latest` to `/releases`
2. Add pagination loop (`page` 1-10), fetch release list per page
3. Inner loop over releases in page, check each release's assets via individual URL call
4. Extract version tag from the found asset's download URL
5. Remove the now-unreached `return 0` on error (the function returns early when no asset found after all pages)
6. Update the dead `jq .` error logging (non-JSON response was already crashing there)

**Testing:**
- Container-level: build with `BUILD=nightly`, observe logs for successful provider download
- Unit: simulate by running `func_check_update` logic manually against the GitHub API
