# Random commands

## Update all the Container Images on the Node

```
for IMG in $(docker images --format "{{.Repository}}"); do docker pull $IMG; done
```

## Check the processor architecture of all the images (should be: arm64)
```
for IMG in $(docker images | awk '{ print $1 }'); do docker inspect --format='{{.Architecture}}' $IMG; done
```


## Pull images within Ollama
```
docker exec -it $(docker ps -a | grep "open-webui:ollama" | awk '{print $1}') bash -c "for MODEL in \$(ollama list | awk '{print \$1}'); do ollama pull \$MODEL; done"
```
