# Netscaler CPX POC
Uses Docker Compose to deploy a Netscaler CPX to load balance a simple web site. Requires Docker 1.13 or greater and docker compose.

## Quick Start
1. Clone the repo and enter the directory
```
git clone https://github.com/ryancbutler/NetscalerCPXDemo.git
cd NetscalerCPXDemo
```

2. Run docker-compose. (Scale adjusts the amount of web servers to load balance with the CPX)
```
docker-compose up -d --scale web=3
```

3. Verify CPX is ready by checking the sidecar logs
```
docker logs sidecar
```

4. Check load balanced website at http://dockerhostip:88 with browser or curl (eg. http://192.168.2.17:88). Should report back some docker info that will change on each refresh.

5. Scale additional web servers
```
docker-compose scale web=5
```

6. Verify new containers are added by checking sidecar
```
docker logs sidecar
```





