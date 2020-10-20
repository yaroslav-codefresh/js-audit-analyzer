# js-audit-analyzer

Utility to define which versions of an npm package have / don't have security issues. 
Then define which package depends on this package.

## Dependencies

```
nvm
git
docker
```


## Usage

```
# default -- current working dir
WORKING_DIR="/path/to/dir/with/your/repos"

# default -- $WORKING_DIR/audit-reports
REPORTS_DIR="/path/to/report/dir" 

# default list you can see in the script
SERVICES=(cf-api cf-ui pipeline-manager)

# run the script
curl https://raw.githubusercontent.com/yaroslav-codefresh/js-audit-analyzer/master/run.sh > run.sh
source run.sh <package_name>
```
