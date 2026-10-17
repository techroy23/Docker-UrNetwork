#!/bin/sh
# URNetwork Provider Startup Script (authcode auth)
# -------------------------------------------------
# Exchanges an auth code for a JWT (reusing a valid JWT when possible),
# keeps the provider running, and applies daily updates at UPDATE_TIME UTC.

set -e

. /app/provider_common.sh

AUTH_MODE="authcode"
AUTH_CODE="${1:-$AUTHCODE}"
func_check_authcode

func_bootstrap
