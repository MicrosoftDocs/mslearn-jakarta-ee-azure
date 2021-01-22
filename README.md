# Build and deploy Java EE(Jakarta EE) Application to JBoss EAP on Azure  App Service

In this sample, you can learn how to deploy a Java EE(Jakarta EE) Application to JBoss EAP on Azure App Service.  
This is a general Java EE (Jakarta EE) application. In the project, we used following technologies of Java EE.

* `JAX-RS (JavaTM API for RESTful Web Services)` 
* `JPA (JavaTM Persistence API)`
* `CDI`
* `JSON-B (JavaTM API for JSON Binding)`


### Prerequire for this Module

* Java SE 8 (or 11)
* Azure CLI command
* Azure Subscription
* git command
* Maven command
* MySQL client command
* jq command
* Bash


## List of all source code

After you clone the project, you will see like following files and directories.

```text
├── Azure-MySQL-Setup-For-Sample-App.md
├── README.md
├── pom.xml
├── setup_mysql.sh
├── src
│   ├── main
│   │   ├── java
│   │   │   └── com
│   │   │       └── microsoft
│   │   │           └── azure
│   │   │               └── samples
│   │   │                   ├── JAXRSConfiguration.java
│   │   │                   ├── controllers
│   │   │                   │   ├── CityService.java
│   │   │                   │   └── CountryService.java
│   │   │                   ├── entities
│   │   │                   │   ├── City.java
│   │   │                   │   └── Country.java
│   │   │                   └── rest
│   │   │                       └── WorldServiceEndpoint.java
│   │   ├── resources
│   │   │   └── META-INF
│   │   │       └── persistence.xml
│   │   └── webapp
│   │       └── WEB-INF
│   │           ├── beans.xml
│   │           ├── mysql-ds.xml
│   │           └── web.xml
│   └── test
│       └── java
│           └── com
│               └── microsoft
│                   └── azure
│                       └── samples
│                           └── SampleTest.java
└── world.sql
```


## Overview of the code

In this project, we will access to MySQL DB from Jakarta EE 8 Application.
To connect to the MySQL from Java, you need implement and configure the project with following procedure.

1. Create and Configure as a Jakarta EE 8 Project
2. Add dependency for MySQL JDBC driver 
3. Create a DataSource with JNDI on your Application Server
4. Create a persisteence unit config for JPA on persistence.xml
5. Inject EntityManager Instance
6. Create Entity class and JPA Named Query
7. Configure for working with JAX-RS and JSON-B in JBoss EAP
8. Implement JAX-RS Endpoint
9. Access to the RESTful Endpoint

### 1. Create and Configure as a Jakarta EE 8 Project

In this project, we created Jakarta EE 8 projects. In order to create the Jakarta EE 8 project, we need specify following dependencies on [pom.xml](pom.xml).

```xml
    <jakarta.jakartaee-api.version>8.0.0</jakarta.jakartaee-api.version>
    ....
    <dependency>
      <groupId>jakarta.platform</groupId>
      <artifactId>jakarta.jakartaee-api</artifactId>
      <version>${jakarta.jakartaee-api.version}</version>
      <scope>provided</scope>
    </dependency>
```

### 2. Add dependency for MySQL JDBC driver 

we added a dependency for MySQL JDBC driver as follows on `pom.xml`. If MySQL provide a new version of the JDBC driver, please change the version number.

```xml
    <mysql-jdbc-driver>8.0.22</mysql-jdbc-driver>

    <dependency>
      <groupId>mysql</groupId>
      <artifactId>mysql-connector-java</artifactId>
      <version>${mysql-jdbc-driver}</version>
    </dependency>
```

### 3. Create a DataSource with JNDI on your Application Server

In order to create a DataSource, you need to create a DataSource on your Application Server.  
Following [createMySQLDataSource.sh](src/main/webapp/WEB-INF/createMySQLDataSource.sh) script create the DataSource on JBoss EAP with JBoss CLI command.

```bash
#!/usr/bin/bash

# In order to use the variables in CLI scripts
# https://access.redhat.com/solutions/321513
sed -i -e "s|.*<resolve-parameter-values.*|<resolve-parameter-values>true</resolve-parameter-values>|g" /opt/eap/bin/jboss-cli.xml

/opt/eap/bin/jboss-cli.sh --connect <<EOF
data-source add --name=JPAWorldDataSourceDS \
--jndi-name=java:jboss/datasources/JPAWorldDataSource \
--connection-url=${MYSQL_CONNECTION_URL} \
--driver-name=ROOT.war_com.mysql.cj.jdbc.Driver_8_0 \
--user-name=${MYSQL_USER} \
--password=${MYSQL_PASSWORD} \
--min-pool-size=5 \
--max-pool-size=20 \
--blocking-timeout-wait-millis=5000 \
--enabled=true \
--driver-class=com.mysql.cj.jdbc.Driver \
--jta=true \
--use-java-context=true \
--valid-connection-checker-class-name=org.jboss.jca.adapters.jdbc.extensions.mysql.MySQLValidConnectionChecker \
--exception-sorter-class-name=com.mysql.cj.jdbc.integration.jboss.ExtendedMysqlExceptionSorter
reload --use-current-server-config=true
exit
EOF
```

### 4. Create a persisteence unit config for JPA on persistence.xml

After created the DataSource, you need create persistence unit config on [persistence.xml](src/main/resources/META-INF/persistence.xml) which is the configuration file of JPA.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<persistence version="2.2" xmlns="http://xmlns.jcp.org/xml/ns/persistence" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://xmlns.jcp.org/xml/ns/persistence http://xmlns.jcp.org/xml/ns/persistence/persistence_2_2.xsd">
  <persistence-unit name="JPAWorldDatasourcePU" transaction-type="JTA">
    <jta-data-source>java:jboss/datasources/JPAWorldDataSource</jta-data-source>
    <exclude-unlisted-classes>false</exclude-unlisted-classes>
    <properties>
      <property name="hibernate.generate_statistics" value="true" />
    </properties>
  </persistence-unit>
</persistence>
```

### 5. Inject EntityManager Instance

Then you can inject an EntityManager instance from annotated unitName with `@PersistenceContext` like follows.  
In the `CountryService.java` and `CountryService.java` code, you can see the injected  EntityManager instance with @PersistenceContext annotation.

Following is [CityService.java](src/main/java/com/microsoft/azure/samples/controllers/CityService.java)

```java
@Transactional(REQUIRED)
@RequestScoped
public class CityService {

    @PersistenceContext(unitName = "JPAWorldDatasourcePU")
    EntityManager em;

    @Transactional(SUPPORTS)
    public List<City> findOver1MillPopulation(String countrycode) {
        TypedQuery<City> query = em.createNamedQuery("City.findOver1MillPopulation", City.class);
        query.setParameter("countrycode", countrycode);
        return query.getResultList();
    }
}
```

### 6. Create Entity class and JPA Named Query

In the above [CityService.java](src/main/java/com/microsoft/azure/samples/controllers/CityService.java), we implelemted following method to query the cities, which have the population over 1 million.

```java
    @Transactional(SUPPORTS)
    public List<City> findOver1MillPopulation(String countrycode) {
        TypedQuery<City> query = em.createNamedQuery("City.findOver1MillPopulation", City.class);
        query.setParameter("countrycode", countrycode);
        return query.getResultList();
    }
```

In the above code, we created a query as Named Query (`City.findOver1MillPopulation`) of JPA. The named query is defined on the Entity class as [City.java](src/main/java/com/microsoft/azure/samples/entities/City.java) as follows.　And we insert the query parameter as `countrycode` which refer to the `:countrycode` in the named query.

Following `City` Entity class is mapping to the `CITY` table in MySQL as Object-Relational Mapping.

```java
@Entity
@Table(name = "city")
@NamedQueries({ @NamedQuery(name = "City.findAll", query = "SELECT c FROM City c"),
        .....
        @NamedQuery(name = "City.findOver1MillPopulation", query = "SELECT c FROM City c WHERE c.countryCode.code = :countrycode AND c.population > 1000000 ORDER BY c.population DESC") })
public class City implements Serializable {

    private static final long serialVersionUID = 1L;
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Basic(optional = false)
    @Column(name = "ID")
    private Integer id;
    @Basic(optional = false)
    @NotNull
    @Size(min = 1, max = 35)
    @Column(name = "Name")
    private String name;
    @Basic(optional = false)
    @NotNull
    @Size(min = 1, max = 20)
    @Column(name = "District")
    private String district;
    @Basic(optional = false)
    @NotNull
    @Column(name = "Population")
    private int population;
    @JoinColumn(name = "CountryCode", referencedColumnName = "Code")
    @ManyToOne(optional = false, fetch = FetchType.LAZY)
    @JsonbTransient
    private Country countryCode;

    //Added Setter and Getter methods
}
```


### 7. Configure for working with JAX-RS and JSON-B in JBoss EAP

We will implement the standard Jakarta EE 8 API only, so in order to use the JSON-B with JAX-RS. we need configure the following parameter in [web.xml](src/main/webapp/WEB-INF/web.xml) for JBoss EAP App.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<web-app xmlns="http://xmlns.jcp.org/xml/ns/javaee" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://xmlns.jcp.org/xml/ns/javaee http://xmlns.jcp.org/xml/ns/javaee/web-app_4_0.xsd" version="4.0">
    <context-param>
        <param-name>resteasy.preferJacksonOverJsonB</param-name>
        <param-value>false</param-value>
    </context-param>
</web-app>
```

If you didn't configure the above, you may see like following error.  
[Stack Overflow : (De)Serializing JSON on Thorntails Use JSON-B Instead of Jackson](https://stackoverflow.com/questions/61483229/deserializing-json-on-thorntails-use-json-b-instead-of-jackson).

```
2020-04-28 10:19:37,235 WARN  [org.jboss.as.jaxrs] (MSC service thread 1-6) 
WFLYRS0018: Explicit usage of Jackson annotation in a JAX-RS deployment; the
 system will disable JSON-B processing for the current deployment. Consider 
setting the 'resteasy.preferJacksonOverJsonB' property to 'false' to restore
 JSON-B.
```

### 8. Implement JAX-RS Endpoint

Finally, you can implement the JAX-RS endpoint in [WorldServiceEndpoint.java](src/main/java/com/microsoft/azure/samples/rest/WorldServiceEndpoint.java) by injecting the `CityService` which implemented in the above.  
And we configured to use the JSON-B in this project, so it automatically marshall the JSON data from Java object. As a result, it return the JSON data in the response.

```java
@Path("/")
public class WorldServiceEndpoint {

    @Inject
    CityService citySvc;

    @GET
    @Produces(MediaType.APPLICATION_JSON)
    @Path("/countries/{countrycode}")
    public Response getCountry(@PathParam("countrycode") String countrycode) {
        List<City> city = citySvc.findOver1MillPopulation(countrycode);
        GenericEntity<List<City>> genericEntity = new GenericEntity<List<City>>(city) {
        };
        return Response.ok(genericEntity, MediaType.APPLICATION_JSON).build();
    }
}
```

### 9. Access to the RESTful Endpoint

If you specify a country code after the /countries, you can get all the cities, which have population greater than a million within the county

```bash
curl https://jakartaee-app-on-jboss.azurewebsites.net/countries/JPN | jq '.[].name'
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--   100   788  100   788    0     0   2671      0 --:--:-- --:--:-- --:--:--  2662
"Tokyo"
"Jokohama [Yokohama]"
"Osaka"
"Nagoya"
"Sapporo"
"Kioto"
"Kobe"
"Fukuoka"
"Kawasaki"
"Hiroshima"
"Kitakyushu"
```