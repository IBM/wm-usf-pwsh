# Integration Platform Integration Server with JDBC, DB support, CU, CDS, On SQL Server

## Installer Selection

* Integration Server
  + Server
* IS Packages
  + Central User Management
  + Logging Utility
  + Monitor
  + Process Engine (to use contexts mainly)
* Adapters (select after the section above, as the implicit IS selection after the Adapter is not producing the same overall selection)
  + JDBC

Note that Database is required for Central Users / CDS. This template assumes the CU DB is different from the Internal one, which remains "embedded".

## Selection resulted in the following final list:

```txt
  Adapters
      webMethods Adapter 10.3 for JDBC
  Database Configuration
      Integration Server and Microservices Runtime Embedded Database Scripts 10.11
  Infrastructure
      Common C/C++ Runtime
      Event Routing Event Type Store 10.11
      Integration Server
          Adapter Runtime 10.11
          Flat File 10.7
          Integration Core 10.11
      Java
          Java Package Core 11.0
      Libraries
          Shared Libraries 10.11
          Broker Libraries 10.5
          CentraSite Libraries 10.11
          Composite Applications Runtime 10.11
          Database Component Configurator Core 10.11
          Database Driver Libraries 10.11
          Designer Libraries 10.11
          Digital Event Services 10.11
          Glue Libraries 8.0
          Installer Libraries 10.11
          Migration Framework Libraries 10.11
          My webMethods Server Libraries 10.11
          Optimize Libraries 10.11
          Third-Party Libraries
              Application Server Libraries 10.11 for Glassfish
              Base Security Libraries 10.11
              Data Modeling Libraries 10.11
              DBMS Libraries 10.11
              Framework Libraries 10.11 for Spring
              Logging Libraries for Java 10.11
              Multi-Purpose Libraries 10.11 for Java
              Swagger Libraries 10.11
              Third-Party Libraries 10.11 for Apache
              Tool for Apache Ant 10.11
              Tool for Java Service Wrapper 10.11
              Web Service Libraries 10.11
              Web Servlet Libraries 10.11
              XML Binding Libraries 10.11 for JAXB
              XML Parser Libraries 10.11
          Universal Messaging Libraries 10.11
      License
          Agreement 10.11
          Library for Java
          Verifier
      Platform Manager 10.11
      Platform Manager Plug-ins
          Adapter Plug-in 10.11
          Event Routing Plug-in 10.11
          Integration Server Plug-ins
              Server Plug-in 10.11
              Monitor Plug-in 10.11
      Shared Platform
          Platform 10.11
          Bundles
              Shared Bundles 10.11
              BigMemory Max Bundles 4.3
              Broker Bundles 10.5
              Central Security Bundles (ZSL)
                  ZSL esapi Bundle 10.11
              Common Landscape Asset Registry 10.11
              Common Monitoring Provider Bundle
                  API 10.11
              Database Driver Bundles 10.11
              Deployer and Asset Build Environment Bundles 10.11
              Digital Event Services
                  Runtime Bundles 10.11
                  Shared Bundles 10.11
              Event Routing
                  Runtime Bundles 10.11
                  Shared Bundles 10.11
              Installer Bundles 10.11
              Integration Server Bundles 10.11
              License Validator Bundles
              Universal Messaging Bundles 10.11
              Web Services Stack Bundles 10.11
      Web Services Stack
          Core Files 10.11
  Integration Server
      Server 10.11
  Integration Server or Microservices Runtime Libraries
      CentraSite Asset Publisher Support 10.11
      Common Directory Service Support 10.11
      External RDBMS Support 10.11
  Integration Server or Microservices Runtime Packages
      Central User Management 10.11
      Logging Utility 9.6
      Monitor 10.11
      Process Engine 10.11
      Process Model Support 10.11
  webMethods Metering
      Metering Agent 10.11
```
