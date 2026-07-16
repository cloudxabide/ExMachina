# Random commands

## Update all the Container Images on the Node

```
for IMG in $(docker images --format "{{.Repository}}"); do docker pull $IMG; done
```

## Check the processor architecture of all the images (should be: arm64)
### Cuda is listed as amd64, somehow
```
for IMG in $(docker images | awk '{ print $1 }'); do echo $IMG; docker inspect --format='{{.Architecture}}' $IMG; echo; done
```

## Pull images within Ollama
```
docker exec -it $(docker ps -a | grep "open-webui:ollama" | awk '{print $1}') bash -c "for MODEL in \$(ollama list | awk '{print \$1}'); do ollama pull \$MODEL; done"
```

## Retrieve your passwd
```
nemoclaw wheatley dashboard-url --quiet
# or
docker exec -it $(docker ps -a | grep "openshell/sandbox-from" | awk '{ print $1 }') /bin/bash -c "jq -r '.gateway.auth.token' /sandbox/.openclaw/openclaw.json"
```

## Allow external connections
```
export MYSANDBOX_NAME="wheatley"
openshell forward stop 18789 $MYSANDBOX_NAME
openshell forward start --background 0.0.0.0:18789 $MYSANDBOX_NAME
# openshell forward stop 18789 $MYSANDBOX_NAME
```

## Get your token
```
jradtke@wheatley:~> docker exec -it $(docker ps -a | grep "openshell/sandbox-from" | awk '{ print $1 }') /bin/bash -c "jq -r '.gateway.auth.token' /sandbox/.openclaw/openclaw.json"
frc-asdfsdfasdfsdafsadfads

```

## Inspect running docker container
```
  nemoclaw $MYSANDBOX_NAME connect
openclaw pairing list --channel $MYSANDBOX_NAME 
openclaw status --all

```
