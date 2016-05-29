DOCKER_IMAGE_VERSION=5.1.2
DOCKER_IMAGE_NAME=robinthrift/seafile
DOCKER_IMAGE_TAGNAME=$(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_VERSION)

default: build

build:
	docker build -t $(DOCKER_IMAGE_TAGNAME) .
	docker tag -f $(DOCKER_IMAGE_TAGNAME) $(DOCKER_IMAGE_NAME):latest

push:
	docker push $(DOCKER_IMAGE_NAME)

test:
	docker run --rm -p 8000:8000 -p 8082:8082 $(DOCKER_IMAGE_TAGNAME)
