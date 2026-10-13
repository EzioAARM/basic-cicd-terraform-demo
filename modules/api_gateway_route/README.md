# api_gateway_route

Crea **un segmento de path** en API Gateway REST con sus métodos e integraciones. Soporta dos tipos de integración:

- `HTTP_PROXY` (default): hacia un backend a través de un VPC Link.
- `AWS_PROXY`: directo hacia una función Lambda.

Cada invocación del módulo maneja un solo `path_part`. Para rutas anidadas se encadenan varias instancias usando el output `resource_id` como `parent_resource_id` del siguiente nivel, así que la profundidad no está limitada.

## Recursos que crea

- `aws_api_gateway_resource` (un segmento)
- `aws_api_gateway_method` — uno por cada método en `methods`
- `aws_api_gateway_integration` — una por cada método, tipo `HTTP_PROXY` vía `VPC_LINK` o `AWS_PROXY` hacia Lambda

## Uso

### Ruta simple sin autenticación

```hcl
module "route_login" {
  source             = "../api_gateway_route"
  rest_api_id        = module.api_gateway.api_gateway_id
  parent_resource_id = module.api_gateway.rest_api_root_resource_id
  path               = "login"
  methods            = ["ANY"]
  authorization      = "NONE"
  vpc_link_id        = module.api_gateway.vpc_link_id
  backend_uri        = "http://${module.api_gateway.alb_dns_name}"
}
```

Resultado: `ANY /login` → `http://<alb-dns>/login`, sin authorizer.

### Ruta con autenticación Cognito y métodos específicos

```hcl
module "route_users" {
  source             = "../api_gateway_route"
  rest_api_id        = module.api_gateway.api_gateway_id
  parent_resource_id = module.api_gateway.rest_api_root_resource_id
  path               = "users"
  methods            = ["GET", "POST"]
  authorization      = "COGNITO_USER_POOLS"
  authorizer_id      = module.api_gateway.cognito_authorizer_id
  vpc_link_id        = module.api_gateway.vpc_link_id
  backend_uri        = "http://${module.api_gateway.alb_dns_name}"
}
```

Resultado: `GET /users` y `POST /users`, ambos protegidos por Cognito.

### Ruta hacia Lambda (AWS_PROXY)

```hcl
module "route_visits" {
  source             = "../api_gateway_route"
  rest_api_id        = module.rest_api.api_gateway_id
  parent_resource_id = module.route_api.resource_id
  path               = "visits"
  methods            = ["GET", "POST"]
  integration_type   = "AWS_PROXY"
  lambda_invoke_arn  = module.lambda.invoke_arn
}
```

Con `AWS_PROXY` la integración siempre usa `POST` hacia Lambda (requisito de API Gateway) y no se usa `vpc_link_id` ni `backend_uri`. El permiso de invocación se declara en la Lambda (`invoke_permissions` del módulo `lambda_function`).

### Catch-all proxy

```hcl
module "route_proxy" {
  source             = "../api_gateway_route"
  rest_api_id        = module.api_gateway.api_gateway_id
  parent_resource_id = module.api_gateway.rest_api_root_resource_id
  path               = "{proxy+}"
  methods            = ["ANY"]
  authorization      = "COGNITO_USER_POOLS"
  authorizer_id      = module.api_gateway.cognito_authorizer_id
  vpc_link_id        = module.api_gateway.vpc_link_id
  backend_uri        = "http://${module.api_gateway.alb_dns_name}"
  is_proxy_route     = true
}
```

Con `is_proxy_route = true` la integración apunta a `<backend_uri>/{proxy}` y se agrega el mapping de `method.request.path.proxy` → `integration.request.path.proxy`.

### Rutas anidadas: `/api/v1/users`

Los segmentos intermedios se crean con `methods = []` para que solo sirvan de padre:

```hcl
module "route_api" {
  source             = "../api_gateway_route"
  rest_api_id        = module.api_gateway.api_gateway_id
  parent_resource_id = module.api_gateway.rest_api_root_resource_id
  path               = "api"
  methods            = []
  vpc_link_id        = module.api_gateway.vpc_link_id
  backend_uri        = "http://${module.api_gateway.alb_dns_name}"
}

module "route_api_v1" {
  source             = "../api_gateway_route"
  rest_api_id        = module.api_gateway.api_gateway_id
  parent_resource_id = module.route_api.resource_id
  path               = "v1"
  methods            = []
  vpc_link_id        = module.api_gateway.vpc_link_id
  backend_uri        = "http://${module.api_gateway.alb_dns_name}"
}

module "route_api_v1_users" {
  source             = "../api_gateway_route"
  rest_api_id        = module.api_gateway.api_gateway_id
  parent_resource_id = module.route_api_v1.resource_id
  path               = "users"
  methods            = ["GET", "POST"]
  authorization      = "COGNITO_USER_POOLS"
  authorizer_id      = module.api_gateway.cognito_authorizer_id
  vpc_link_id        = module.api_gateway.vpc_link_id
  backend_uri        = "http://${module.api_gateway.alb_dns_name}"
}
```

## Variables

| Nombre               | Tipo           | Requerido        | Default        | Descripción                                                                                                                                         |
| -------------------- | -------------- | ---------------- | -------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| `rest_api_id`        | `string`       | sí               | —              | ID del REST API donde se crea la ruta.                                                                                                              |
| `parent_resource_id` | `string`       | sí               | —              | ID del recurso padre. Para rutas de primer nivel usa el `rest_api_root_resource_id`; para anidadas, el `resource_id` del nivel anterior.            |
| `path`               | `string`       | sí               | —              | Segmento del path, sin slash inicial. Ejemplos: `login`, `users`, `{proxy+}`, `{id}`.                                                               |
| `integration_type`   | `string`       | no               | `"HTTP_PROXY"` | `HTTP_PROXY` (VPC Link) o `AWS_PROXY` (Lambda).                                                                                                     |
| `vpc_link_id`        | `string`       | con `HTTP_PROXY` | `null`         | ID del VPC Link usado por la integración.                                                                                                           |
| `lambda_invoke_arn`  | `string`       | con `AWS_PROXY`  | `null`         | `invoke_arn` de la Lambda.                                                                                                                          |
| `backend_uri`        | `string`       | con `HTTP_PROXY` | `""`           | URI base del backend, sin trailing slash. Ejemplo: `http://internal-alb.elb.amazonaws.com`. El path se concatena automáticamente.                   |
| `methods`            | `list(string)` | no               | `["ANY"]`      | Métodos HTTP a crear. Lista vacía crea solo el segmento sin métodos, útil para niveles intermedios.                                                 |
| `authorization`      | `string`       | no               | `"NONE"`       | Tipo de autorización: `NONE`, `COGNITO_USER_POOLS`, `CUSTOM`, `AWS_IAM`.                                                                            |
| `authorizer_id`      | `string`       | no               | `null`         | ID del authorizer. Requerido cuando `authorization` es distinto de `NONE`; se ignora cuando es `NONE`.                                              |
| `is_proxy_route`     | `bool`         | no               | `false`        | Configura la ruta como proxy pass-through: integración a `<backend_uri>/{proxy}` y mapping del path parameter. Úsalo junto con `path = "{proxy+}"`. |

## Outputs

| Nombre            | Descripción                                                                      |
| ----------------- | -------------------------------------------------------------------------------- |
| `resource_id`     | ID del recurso creado. Se pasa como `parent_resource_id` para crear rutas hijas. |
| `method_ids`      | Map de método HTTP → ID del `aws_api_gateway_method`.                            |
| `integration_ids` | Map de método HTTP → ID del `aws_api_gateway_integration`.                       |

## Notas

- Las validaciones cruzadas entre variables (`vpc_link_id` / `lambda_invoke_arn` según `integration_type`) requieren **Terraform 1.9 o superior**.

- API Gateway REST da prioridad a los recursos explícitos sobre `{proxy+}`. Una ruta `/login` con `authorization = "NONE"` se resuelve antes que el catch-all protegido, así que conviven sin conflicto.
- El `integration_http_method` se deriva de cada método: `ANY` se mapea a `ANY` y el resto se mapea a sí mismo.
- Los recursos usan `for_each` sobre `methods`, así que sus direcciones en el state incluyen la clave del método: `module.route_login.aws_api_gateway_method.this["ANY"]`. Tenlo en cuenta al hacer `terraform state mv` o `import`.
- Este módulo no crea el deployment ni el stage. Después de definir las rutas, crea un `aws_api_gateway_deployment` con `depends_on` hacia los módulos de ruta y `lifecycle { create_before_destroy = true }`.
