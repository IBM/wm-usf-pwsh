# Detailed Selection Trace

The following selection was done for preparing a script to generate a products image.

## Selection

* Asset Build Environment
* Integration Server -> Server
* Integration Server / Libraries
  + CDS Support
  + External RDBMS Support
* Integration Server / Packages
  + Central Users Management
  + Deployer with all options
  + Logging Utility
  + Monitor
  + Process Engine
  + Unit Test Framework
* My WebMethods Server
  + Server Only
* MWS UIs
  + IS UI
  + Monitor UI
  + FIX Module 7.2
* Universal Messaging - All
* Adapters
  + JDBC
  + PeopleSoft Enterprise One

## First dependency resolution

```txt
Universal Messaging > Client Libraries requires Libraries > Common Libraries for OpenSSL.
Adapters > webMethods Adapter for JDBC requires Integration Server > Integration Core.
Integration Server or Microservices Runtime Packages > Deployment Support for Universal Messaging requires Integration Server > Integration Core.
Integration Server or Microservices Runtime Libraries > External RDBMS Support requires Integration Server > Integration Core.
Integration Server or Microservices Runtime Packages > Deployment Support for CloudStreams requires Integration Server > Integration Core.
My webMethods User Interfaces > Monitor UI requires Libraries > Optimize Libraries.
Asset Build Environment requires Asset Build Environment Scripts > Integration Server Assets.
Integration Server or Microservices Runtime Libraries > Common Directory Service Support requires Libraries > Composite Applications Runtime.
Universal Messaging > Broker to UM Migration Utility requires Libraries > Shared Libraries.
Integration Server or Microservices Runtime Packages > Deployer requires Integration Server > Integration Core.
Integration Server or Microservices Runtime Packages > Central User Management requires Integration Server > Integration Core.
Integration Server or Microservices Runtime Packages > Unit Test Framework requires Integration Server > Integration Core.
Integration Server or Microservices Runtime Packages > Deployment Support for webMethods Broker requires Integration Server > Integration Core.
Integration Server or Microservices Runtime Packages > Monitor requires Integration Server > Integration Core.
Integration Server or Microservices Runtime Packages > Logging Utility requires Integration Server > Integration Core.
Universal Messaging > Instance Manager requires Platform Manager Plug-ins > Universal Messaging Plug-in.
Integration Server > Server requires Integration Server > Integration Core.
Integration Server or Microservices Runtime Packages > Deployment Support for AgileApps requires Integration Server > Integration Core.
My webMethods Server > Server requires My webMethods Server Plug-ins > Server Plug-in.
Integration Server or Microservices Runtime Packages > Process Engine requires Libraries > Shared Libraries.
Universal Messaging > Realm Server requires webMethods Metering > Metering Agent.
Libraries > Common Libraries for OpenSSL requires Libraries > Installer Libraries.
Integration Server > Integration Core requires Integration Server > Adapter Runtime.
Shared User Interface > Optimize Support requires Libraries > Optimize Libraries.
Libraries > Optimize Libraries requires Web Services Stack > Core Files.
Bundles > Composite Applications Runtime Bundles requires Bundles > Integration Server Bundles.
Libraries > Shared Libraries requires Libraries > Migration Framework Libraries.
Libraries > Broker Libraries requires Libraries > Shared Libraries.
Libraries > My webMethods Server Libraries requires Libraries > Shared Libraries.
Libraries > Composite Applications Runtime requires Libraries > Shared Libraries.
Web Services Stack > Core Files requires Third-Party Libraries > Web Service Libraries.
Event Routing > Shared Bundles requires Bundles > Deployer and Asset Build Environment Bundles.
Libraries > Universal Messaging Libraries requires Third-Party Libraries > Data Modeling Libraries.
Libraries > Designer Libraries requires Libraries > Shared Libraries.
Libraries > BigMemory Max Libraries requires Third-Party Libraries > Tool for Apache Ant.
Asset Build Environment Scripts > Command Central Assets requires Infrastructure > Platform Manager.
Libraries > Migration Framework Libraries requires Third-Party Libraries > Logging Libraries for Java.
Platform Manager Plug-ins > Universal Messaging Plug-in requires Common Monitoring Provider Bundle > Implementations.
Integration Server Plug-ins > Server Plug-in requires Infrastructure > Platform Manager.
Shared Platform > Platform requires Central Security Bundles (ZSL) > ZSL esapi Bundle.
Event Routing > Runtime Bundles requires Third-Party Libraries > Framework Libraries for Spring.
Digital Event Services > Runtime Bundles requires Digital Event Services > Shared Bundles.
Integration Server or Microservices Runtime Libraries > CentraSite Asset Publisher Support requires Integration Server > Integration Core.
Bundles > Database Driver Bundles requires Bundles > Shared Bundles.
My webMethods Server Plug-ins > Server Plug-in requires Common Monitoring Provider Bundle > Implementations.
My webMethods Server > Diagnostic Tools requires Bundles > Composite Applications Runtime Bundles.
Bundles > Common Landscape Asset Registry requires Bundles > Shared Bundles.
Integration Server or Microservices Runtime Packages > Process Model Support requires Integration Server > Integration Core.
webMethods Metering > Metering Agent requires Libraries > Migration Framework Libraries.
Database Configuration > Integration Server and Microservices Runtime Embedded Database Scripts requires Libraries > Database Component Configurator Core.
Integration Server > Flat File requires Integration Server > Integration Core.
Integration Server > Adapter Runtime requires Integration Server > Integration Core.
Bundles > Glue Bundles requires Bundles > Shared Bundles.
Bundles > Web Services Stack Bundles requires Shared Platform > Platform.
Bundles > Universal Messaging Bundles requires Bundles > Installer Bundles.
Bundles > Broker Bundles requires Bundles > Deployer and Asset Build Environment Bundles.
Infrastructure > Platform Manager requires Libraries > Shared Libraries.
Common Monitoring Provider Bundle > Implementations requires Common Monitoring Provider Bundle > API.
Central Security Bundles (ZSL) > ZSL esapi Bundle requires Bundles > Shared Bundles.
Platform Manager Plug-ins > Event Routing Plug-in requires Bundles > Web Services Stack Bundles.
Infrastructure > Event Routing Event Type Store requires Libraries > Shared Libraries.
Libraries > Digital Event Services requires Libraries > Shared Libraries.
Digital Event Services > Shared Bundles requires Libraries > Shared Libraries.
Bundles > Installer Bundles requires Shared Platform > Platform.
License > Verifier requires Infrastructure > Common C/C++ Runtime.
Infrastructure > Common C/C++ Runtime requires Libraries > Installer Libraries.
```

## Selection #2

* Full Database Configuration
* Big Memory Max
* CloudStreams Server

## Dependencies Resolution #2

```text
CloudStreams Server requires Runtime.
BigMemory Max requires Platform Manager Plug-ins > BigMemory Max Plug-in.
```
