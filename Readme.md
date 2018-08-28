# RbShift usage

## Obtaining client
Client object is the starting point of interaction with Openshift, it can be created either by
providing __bearer token__ or __username and password__.

```ruby
require 'rb_shift/client'

# Getting client with token
cli = RbShift::Client.new 'https.ose3.example.com:8443', bearer_token: 'SomeToken'

# Getting client with username/password
cli2 = RbShift::Client.new 'https.ose3.example.com:8443', username: 'admin', password: 'P@ssw0rd'
```

## Working with projects

All resources in openshift are created and managed in projects.

```ruby
# Get list of projects
projects = cli.projects

# selecting specific project
my_proj = projects['MyAwesomeProject']

# Delete project without waiting
my_proj.delete

# Delete project and wait until it disappears
my_proj.delete true

# Create new project
my_proj = cli.create_project 'AwesomeProject'
```

## Creating template and deploying application

```ruby
# Create template from url
my_proj.create_template 'http://example.com/template.yml'

# Create template from file
my_proj.create_template '/home/user/template.yml'

# Start application from template this will be translated to oc command
# oc new-app template TemplateName --param='param1=Value1' --param='param2=Value2' --env='SOME_VAR=Value3' --group='gr1' --group='gr2'
# This command is blocking
my_proj.new_app 'template', 'TemplateName', block: true, timeout: 30, param: 
  {
    param1: 'Value1',
    param2: 'Value2',
  }, 
  env: {
   SOME_VAR: 'Value3',
  }, 
  group:
  [
    'Gr1',
    'Gr2',
  ]
  
# Start application asynchronously
my_proj.new_app 'template', 'TemplateName'

# Wait for deployments to finish without 
my_proj.wait_for_deployments
```

## Redeploy component
```ruby
# Find DeploymentConfig to redeploy
dc = my_proj.deployments['DCName']

# Start deployment asynchronously
dc.start_deployment

# Start deployment and block until it finishes with specified timeout
dc.start_deployment block: true, timeout: 30
```

## Creating route
```ruby
# Find service to expose
service = my_proj.services['ServiceName']

# Create edge terminated https route (encrypted by default router's certificate)
service.create_route 'Route1', 'route1.example.com'

# Create unencrypted route
service.create_route 'Route2', 'route2.example.com', nil

# Create route encrypted by service's certificate
service.create_route 'Route3', 'route3.example.com', 'passthrough'

# Create route encrypted by custom certificate
service.create_route 'Route4', 'route4.example.com', 'ca-cert': '/home/user/ca.pem', cert: '/home/user/cert.pem', key: '/home/user/key.pem'
```


## Env Variables

Logging related:

```shell
RB_SHIFT_LOG_LEVEL=(debug|info|warn|error)
RB_SHIFT_LOG_RESPONSES=(true|false)
```