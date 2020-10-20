default_services=(
  'cf-api'
  'context-manager'
  'runtime-environment-manager'
  'engine'
  'cf-broadcaster'
  'pipeline-manager'
  'tasker-kubernetes'
  'charts-manager'
  'cluster-providers'
  'kube-integration'
)

services=("${SERVICES[@]-${default_services[@]}}")

package_name="$1"
current_dir=$(pwd)
working_dir=${WORKING_DIR-$current_dir}
reports_dir=${REPORTS_DIR-"$working_dir/audit-reports"}
report_file="$reports_dir/$1"
trivy_cache_dir="$HOME/.cache/trivy"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

function echo_e() {
  echo -e "$1"
}
function red() {
  echo_e "${RED}$1${NC}"
}
function green() {
  echo_e "${GREEN}$1${NC}"
}
function print_delimiter() {
  echo_e "-----------------"
}
function print_report() {
  echo_e "$1" >>"$report_file"
}

export echo_e
export red
export green
export print_delimiter
export print_report

################### code

### clone repos
echo_e "$(green 'STEP 1:') Cloning repos:"
cd "$working_dir"
for service_name in "${services[@]}"; do
  print_delimiter
  git clone git@github.com:codefresh-io/"$service_name".git
  print_delimiter
done

### pulling the image to validate for security issues
echo_e "$(green 'STEP 2:') Preparing analyzing tool..."
docker pull aquasec/trivy

### prepare output directory and file
echo_e "$(green 'STEP 3:') Preparing output dir and file..."
mkdir -p "$reports_dir"
echo_e "$(green 'STEP 3:') Output dir is ready: $(red "$reports_dir")"
rm "$report_file"
touch "$report_file"
echo_e "$(green 'STEP 3:') Output file is ready: $(red "$report_file")"

### prepare trivy db dir and download the db itself
echo_e "$(green 'STEP 4:') Preparing analyzing tool cache dir: $(red "$trivy_cache_dir")"
mkdir -p "$trivy_cache_dir"
echo_e "$(green 'STEP 4:') Downloading analyzing tool vulnerabilities db..."
docker run --rm -v "$trivy_cache_dir":/root/.cache aquasec/trivy --download-db-only
echo_e "$(green 'STEP 4:') Analyzing tool is ready"

echo_e "$(green 'STEP 5:') Scanning repos in working_dir: $(red "$working_dir")"
for service_name in "${services[@]}"; do
  service_dir="$working_dir/$service_name"

  print_delimiter
  echo_e "Using $(red "$service_name")"
  cd "$service_dir"

  # prepare repo yarn
  echo_e "$(red "($service_name)") Installing dependencies..."
  node_version=$(jq -r .engines.node package.json)
  nvm install "$node_version"
  nvm use "$node_version"
  yarn

  echo_e "$(red "($service_name)") Defining security vulnerabilities..."
  analyzer_output="$(
    docker run \
      --rm \
      -v "$trivy_cache_dir":/root/.cache \
      -v "$service_dir":/service \
      aquasec/trivy \
      fs \
      --skip-update \
      /service | grep "LIBRARY\|$package_name"
  )"

  echo_e "$(red "($service_name)") Defining dependencies..."
  deps_output="$(
    docker run \
      -v "$service_dir":/service \
      yaroslavcodefresh/yarn-dep-inspector \
      inspect "$package_name" --wd /service
  )"

  echo_e "$(red "($service_name)") Printing to file..."

  print_report "---------------$service_name---------------"
  print_report "---PROBLEMATIC PACKAGE---"
  print_report "$analyzer_output"
  print_report "$(echo)"

  print_report "---DEPENDENCIES---"
  print_report "$deps_output"
  print_report "---------------$service_name---------------\n\n"

  cd "$current_dir"

  print_delimiter

done

echo_e "$(green "FINAL:") Reports written to file: $(red "$report_file")"
