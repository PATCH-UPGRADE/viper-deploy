# Shared configuration for the IV&V metric init scripts. Source this; do not run it.
#
#   VIPER_TARGET=aws   (default) -> compose-aws.yml via podman-compose  (the deployed box)
#   VIPER_TARGET=dev             -> compose.dev.yml via docker compose  (a local laptop)
#
# Individual overrides win over the target defaults:
#   VIPER_DEPLOY_ROOT   repo root (defaults to this checkout; /srv/viper-deploy on AWS)
#   VIPER_COMPOSE_FILE  compose file to drive
#   VIPER_COMPOSE_CMD   "podman-compose" or "docker compose"
#   VIPER_CONTAINER_CMD "podman" or "docker"
#   VIPER_ENV_FILE      shared VIPER env file (defaults to assets/.env)

if [ -z "${VIPER_DEPLOY_ROOT:-}" ]; then
    # assets/ivv_metrics/lib/common.sh -> repo root
    VIPER_DEPLOY_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
fi
ASSETS_DIR="${VIPER_DEPLOY_ROOT}/assets"

VIPER_TARGET="${VIPER_TARGET:-aws}"
case "${VIPER_TARGET}" in
    aws)
        : "${VIPER_COMPOSE_FILE:=${ASSETS_DIR}/compose-aws.yml}"
        : "${VIPER_COMPOSE_CMD:=podman-compose}"
        : "${VIPER_CONTAINER_CMD:=podman}"
        ;;
    dev)
        : "${VIPER_COMPOSE_FILE:=${ASSETS_DIR}/compose.dev.yml}"
        : "${VIPER_COMPOSE_CMD:=docker compose}"
        : "${VIPER_CONTAINER_CMD:=docker}"
        ;;
    *)
        echo "ERROR: unknown VIPER_TARGET '${VIPER_TARGET}' (expected 'aws' or 'dev')" >&2
        exit 1
        ;;
esac

VIPER_ENV_FILE="${VIPER_ENV_FILE:-${ASSETS_DIR}/.env}"
if [ ! -r "${VIPER_ENV_FILE}" ]; then
    echo "ERROR: shared VIPER env file not found: ${VIPER_ENV_FILE}" >&2
    echo "  deployed box: cp ${ASSETS_DIR}/.env.aws.example ${VIPER_ENV_FILE}" >&2
    echo "  local docker: cp ${ASSETS_DIR}/.env.local.example ${VIPER_ENV_FILE}" >&2
    exit 1
fi

# Export the shared env so compose can interpolate ${VIPER_VERSION} and integrate.sh can
# read ${BLUEFLOW_API_TOKEN} -- identically under podman-compose and docker compose, with
# no dependency on --env-file flag semantics. Parsed rather than sourced so the file cannot
# execute anything; a value already set in the environment wins, as it does in compose.
while IFS= read -r line || [ -n "${line}" ]; do
    case "${line}" in ''|'#'*) continue ;; esac
    case "${line}" in 'export '*) line=${line#export } ;; esac
    key=${line%%=*}
    value=${line#*=}
    case "${key}" in ''|*[!A-Za-z0-9_]*) continue ;; esac
    case "${value}" in
        \"*\") value=${value#\"}; value=${value%\"} ;;
        \'*\') value=${value#\'}; value=${value%\'} ;;
    esac
    if [ -z "${!key+set}" ]; then
        export "${key}=${value}"
    fi
done < "${VIPER_ENV_FILE}"
unset line key value

VIPER_API_KEY_FILE="${VIPER_API_KEY_FILE:-${ASSETS_DIR}/VIPER_API_KEY}"

# VIPER_COMPOSE_CMD is deliberately unquoted: it may be two words ("docker compose").
compose() {
    ${VIPER_COMPOSE_CMD} -f "${VIPER_COMPOSE_FILE}" "$@"
}

container() {
    ${VIPER_CONTAINER_CMD} "$@"
}
