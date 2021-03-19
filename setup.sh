source .env.sh

# Some local properties
DATASOURCE_DIR=$(pwd)/dataset
DATASET_NAME=france_departments_v7.geo.json
DATASET_URL="https://vector.maps.elastic.co/files/$DATASET_NAME"

# Utility functions
check_service () {
	echo -ne '\n'
	echo $1 $ELASTIC_VERSION must be available on $2
	echo -ne "Waiting for $1"

	until curl -u elastic:$ELASTIC_PASSWORD -s "$2" | grep "$3" > /dev/null; do
		  sleep 1
			echo -ne '.'
	done

	echo -ne '\n'
	echo $1 is now up.
}

# Curl Delete call Param 1 is the Full URL, Param 2 is optional text
# curl_delete "$ELASTICSEARCH_URL/foo*" "Fancy text"
# curl_delete "$ELASTICSEARCH_URL/foo*"
curl_delete () {
	if [ -z "$2" ] ; then
		echo "Calling DELETE $1"
	else 
	  echo $2
	fi
  curl -XDELETE "$1" -u elastic:$ELASTIC_PASSWORD -H 'kbn-xsrf: true' ; echo
}

# Curl Post call Param 1 is the Full URL, Param 2 is a json file, Param 3 is optional text
# 
curl_post () {
	if [ -z "$3" ] ; then
		echo "Calling POST $1"
	else 
	  echo $3
	fi
  curl -XPOST "$1" -u elastic:$ELASTIC_PASSWORD -H 'kbn-xsrf: true' -H 'Content-Type: application/json' -d"@$2" ; echo
}

# Curl Post call Param 1 is the Full URL, Param 2 is a json file, Param 3 is optional text
# 
curl_post_form () {
	if [ -z "$3" ] ; then
		echo "Calling POST FORM $1"
	else 
	  echo $3
	fi
  curl -XPOST "$1" -u elastic:$ELASTIC_PASSWORD -H 'kbn-xsrf: true' --form file="@$2" ; echo
}

# Curl Put call Param 1 is the Full URL, Param 2 is a json file, Param 3 is optional text
# 
curl_put () {
	if [ -z "$3" ] ; then
		echo "Calling PUT $1"
	else 
	  echo $3
	fi
  curl -XPUT "$1" -u elastic:$ELASTIC_PASSWORD -H 'kbn-xsrf: true' -H 'Content-Type: application/json' -d"@$2" ; echo
}

# Curl Get call Param 1 is the Full URL, Param 2 is optional text
# 
curl_get () {
	if [ -z "$2" ] ; then
		echo "Calling GET $1"
	else 
	  echo $2
	fi
  curl -XGET "$1" -u elastic:$ELASTIC_PASSWORD ; echo
}

import_geojson () {
    FILE=$DATASOURCE_DIR/$DATASET_NAME
    # We import the file from elastic map service if not available yet
    if [ ! -e $FILE ] ; then
        echo "Fetching $FILE from $DATASET_URL"
        wget $DATASET_URL -O $DATASOURCE_DIR/$DATASET_NAME.gz
        cd $DATASOURCE_DIR
        gunzip $DATASET_NAME.gz
        cd -
    fi
}

# Start of the script
echo Installation script for Ingest Pipelines demo with Elastic $ELASTIC_VERSION

echo "##################"
echo "### Pre-checks ###"
echo "##################"

if [ ! -e $DATASOURCE_DIR ] ; then
    echo "Creating $DATASOURCE_DIR dir"
    mkdir $DATASOURCE_DIR
fi

if [ -z "$CLOUD_ID" ] ; then
	echo "We are running a local demo. If you did not start Elastic yet, please run:"
	echo "docker-compose up"
fi

check_service "Elasticsearch" "$ELASTICSEARCH_URL" "\"number\" : \"$ELASTIC_VERSION\""
check_service "Kibana" "$KIBANA_URL/app/home#/" "<title>Elastic</title>"

echo -ne '\n'
echo "################################"
echo "### Configure Cloud Services ###"
echo "################################"
echo -ne '\n'

curl_delete "$ELASTICSEARCH_URL/kibana_sample_data_ecommerce"
curl_delete "$ELASTICSEARCH_URL/demo-ingest*"
curl_delete "$ELASTICSEARCH_URL/_index_template/demo-ingest"
curl_delete "$ELASTICSEARCH_URL/_ingest/pipeline/demo-ingest*"
curl_delete "$ELASTICSEARCH_URL/_enrich/policy/demo-ingest-regions-policy"

echo -ne '\n'
echo "##################################################"
echo "### Initialize the demo-ingest-regions Dataset ###"
echo "##################################################"
echo -ne '\n'

curl_put "$ELASTICSEARCH_URL/demo-ingest-regions" "elasticsearch-config/demo-ingest-regions.json"

# Download the geojson file if needed.
echo "If you want to download a new version of the france departments, run:"
echo "rm $DATASOURCE_DIR/$DATASET_NAME"
echo ""
echo "And start again this script."
import_geojson

# Parse it and transform to a bulk request
cat $DATASOURCE_DIR/$DATASET_NAME | jq -c '.features | .[] | [{ index : { _id: .properties.insee }}, { region: .properties.insee, name: .properties.label_fr, location: .geometry }] | .[]' > $DATASOURCE_DIR/bulk.ndjson

curl -XPOST "$ELASTICSEARCH_URL/demo-ingest-regions/_bulk" -s -u elastic:$ELASTIC_PASSWORD -H 'Content-Type: application/x-ndjson' --data-binary "@$DATASOURCE_DIR/bulk.ndjson" | jq '{took: .took, errors: .errors}' ; echo

echo -ne '\n'
echo "#####################################"
echo "### Initialize the person Dataset ###"
echo "#####################################"
echo -ne '\n'

curl_put "$ELASTICSEARCH_URL/demo-ingest-person" "elasticsearch-config/demo-ingest-person.json"
curl_put "$ELASTICSEARCH_URL/demo-ingest-person-new" "elasticsearch-config/demo-ingest-person.json"

# It has been generated using the person injector (not public though)
# java -jar injector-7.0.jar --console --nb 1000 > $DATASOURCE_DIR/persons.json
cat dataset/persons.json | jq --slurp -c '.[] | select( .address.country == "France" ) | { index : {  }}, { name: .name, dateofbirth: .dateofbirth, country: .address.country, geo_location: ("POINT (" + (.address.location.lon | tostring)  + " " + (.address.location.lat | tostring) + ")") }' > $DATASOURCE_DIR/bulk-person.ndjson

curl -XPOST "$ELASTICSEARCH_URL/demo-ingest-person/_bulk" -s -u elastic:$ELASTIC_PASSWORD -H 'Content-Type: application/x-ndjson' --data-binary "@$DATASOURCE_DIR/bulk-person.ndjson" | jq '{took: .took, errors: .errors}' ; echo

echo -ne '\n'
echo "#############################"
echo "### Install Canvas Slides ###"
echo "#############################"
echo -ne '\n'

curl_post_form "$KIBANA_URL/api/saved_objects/_import?overwrite=true" "kibana-config/canvas.ndjson"

echo -ne '\n'
echo "#####################"
echo "### Demo is ready ###"
echo "#####################"
echo -ne '\n'

open "$KIBANA_URL/app/canvas#/"

echo "If not yet there, paste the following script in Dev Tools:"
cat elasticsearch-config/devtools-script.json
echo -ne '\n'

