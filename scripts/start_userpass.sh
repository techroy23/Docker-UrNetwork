#!/bin/sh
# URNetwork Provider Startup Script (userpass auth)
# -------------------------------------------------
# Logs in with USER_AUTH + PASSWORD (reusing a valid JWT when possible),
# keeps the provider running, and applies daily updates at UPDATE_TIME UTC.

set -e

. /app/provider_common.sh

AUTH_MODE="userpass"
func_check_credentials

func_bootstrap
