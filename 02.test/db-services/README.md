# Support Services for Template Testing

These services are provided as a convenience for testing templates requiring other services, such as databases or messaging providers.

Although convenient for their convenient provisioning, these services are not reachable directly from the sandbox.

In order to reach them please ensure the following:

1. The services are exposed on an IP reachable from the Sandbox
2. The firewall is open

Assuming the host is a Windows 11, the containers are spun using Rancher Desktop, the user may have local addresses like

* 172.18.*.* for Rancher Desktop and containers addressing
* 172.28.*.* for Sandbox IPs.

In this case, pick the sandbox gateway address, and execute the following commands.

```bat
SET SANDBOX_GATEWAY_IP=__your_sandbox_subnet_gateway_ip__
```

E.g. gor gateway 172.28.224.1

```bat
SET SANDBOX_GATEWAY_IP=172.28.224.1
```

## Open Services

Run these as Administrator from command line (not PowerShell)

```bat
netsh interface portproxy add v4tov4 listenaddress=%SANDBOX_GATEWAY_IP% listenport=1433 connectaddress=host.docker.internal connectport=1433
netsh interface portproxy add v4tov4 listenaddress=%SANDBOX_GATEWAY_IP% listenport=8080 connectaddress=host.docker.internal connectport=8080
netsh advfirewall firewall add rule name="Allow sbx services" dir=in action=allow protocol=TCP localport=8080,1433 localip=%SANDBOX_GATEWAY_IP% remoteip=LocalSubnet
```

## Inspect Rules

```bat
netsh interface portproxy show v4tov4
netsh advfirewall firewall show rule name="Allow sbx services"
```

## Cleanup 

```bat
netsh interface portproxy delete v4tov4 listenaddress=%SANDBOX_GATEWAY_IP% listenport=1433
netsh interface portproxy delete v4tov4 listenaddress=%SANDBOX_GATEWAY_IP% listenport=8080
netsh advfirewall firewall delete rule name="Allow sbx services"
```
