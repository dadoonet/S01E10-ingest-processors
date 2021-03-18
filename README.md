# Demo scripts used for Elastic Daily Bytes - Ingest Processors

![Ingest Processors](images/00-talk.png "Ingest Processors")

## Setup

The setup will check that Elasticsearch and Kibana are running and will remove index named `kibana_sample_data_ecommerce`, `demo-ingest*`, the index templates `demo-ingest` and any ingest pipeline named `demo-ingest-*`.

It will also add Kibana Canvas slides.

### Run on cloud (recommended)

This specific configuration is used to run the demo on a [cloud instance](https://cloud.elastic.co).
You need to create a `.cloud` local file which contains:

```
CLOUD_ID=the_cloud_id_you_can_read_from_cloud_console
CLOUD_PASSWORD=the_generated_elastic_password
```

Run:

```sh
./setup.sh
```

### Run Locally

Run Elastic Stack:

```sh
docker-compose down -v
docker-compose up
```

And run:

```sh
./setup.sh
```

## Ingest Pipeline

This picture describes how an ingest pipeline is working.

![Ingest Processors](images/10-ingest.svg "Ingest Processors")


## Demo part

### Circle Ingest Processor

Adapted from the [7.4.0 release notes](https://www.elastic.co/blog/elasticsearch-7-4-0-released):

> Before this processor, when ingesting and indexing a circle into Elasticsearch, users had two options:
> 
> * Ingest and index the circle using a prefix tree - this option is simple to do, but results in a slower and larger index (since this method does not enjoy the benefits of the BKD-Tree) - this was the “easy way”
> * Provide Elasticsearch with a polygon that closely resembles the circle before ingestion and index that polygon - this option provides a smaller and better performing index (since it does use the BKD-Tree) - but the user was responsible for translating the circle into a polygon in an efficient and accurate way, which is not trivial - this was the “efficient way”
> 
> The circle ingest processor translates circles into polygons that closely resemble them as part of the ingest process, which means ingesting, indexing, searching, and aggregating circles, just became both easy and efficient.

This processor is doing some approximation behind the scene.

![Ingest Processors](images/21-error_distance.png "Ingest Processors")

Open Stack Management / Ingest Node Pipelines and create a new pipeline `demo-ingest-circle`.
Add a `Circle` processor on `circle` field with a `Geo-shape` Shape type.

![Ingest Processors](images/20-add-circle-pipeline.png "Ingest Processors")

Add 2 documents to test the processor:

```json
[
  {
    "_source": {
      "circle": "CIRCLE (30 10 40)"
    }
  },
  {
    "_source": {
      "circle": {
        "type": "circle",
        "radius": "40m",
        "coordinates": [
          30,
          10
        ]
      }
    }
  }
]
```

Adjust the Error distance to `100` and show the effect when running again the test.

You can now "Save the pipeline".



