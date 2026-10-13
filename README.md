# Terraform en la construcción de arquitecturas · Demo

Código de la demo de la conferencia **"Cloud Computing: Terraform en la construcción de arquitecturas"**.

Despliega una arquitectura serverless completa en AWS:

```
Usuario ──► S3 static website (frontend)
   │
   └── /api/* ──► API Gateway REST ──► Lambda ──► DynamoDB
```

## Cómo está organizado

Los **módulos son bloques reutilizables por servicio** (`dynamo_table`, `lambda_function`, `api_gateway_route`…). No saben nada de esta aplicación: reciben nombres, ARNs y opciones, y aplican los estándares (cifrado, bloqueo de acceso público, retención de logs).

El **proyecto** (`main.tf`) es quien arma la arquitectura: llama a los módulos, conecta las salidas de uno con las entradas de otro y agrupa el código por capa.

```
.
├── bootstrap/
│   ├── terraform-backend.yaml     # CloudFormation: bucket S3 del state
│   └── terraform-pipeline.yaml    # CloudFormation: pipeline (plan → aprobación → apply)
├── modules/                       # Bloques reutilizables por servicio
│   ├── dynamo_table/
│   ├── lambda_function/
│   ├── api_gateway_rest_api/
│   ├── api_gateway_route/
│   ├── api_gateway_deployment/
│   ├── s3/
│   └── cloudfront_distribution/   # No se usa en la demo (tarda varios minutos en crearse)
├── src/
│   ├── api/index.mjs              # Lambda: contador de visitas
│   └── web/index.html             # Frontend
├── main.tf                        # Punto de entrada para terraform
├── provider.tf                    # Definición del provider de AWS
├── variables.tf                   # Variables requeridas para desplegar la infraestructura
├── outputs.tf                     # URLs del frontend y de la API
└── .checkov.yaml                  # Excepciones de seguridad documentadas
```

| Capa    | Módulos                                                                    |
| ------- | -------------------------------------------------------------------------- |
| Datos   | `dynamo_table`                                                             |
| Cómputo | `lambda_function`                                                          |
| API     | `api_gateway_rest_api`, `api_gateway_route` (×2), `api_gateway_deployment` |
| Borde   | `s3`                                                                       |

Las rutas se encadenan: `route_api` crea `/api` (sin métodos) y `route_visits` crea `/api/visits` usando `module.route_api.resource_id` como padre.

## Requisitos

- Terraform **1.10 o superior** (por `use_lockfile` y las validaciones entre variables). También funciona con OpenTofu 1.10+.
- AWS CLI v2 con credenciales temporales (recomendado: IAM Identity Center / SSO).
- Permisos para crear: S3, Lambda, API Gateway, DynamoDB, IAM roles y CloudWatch Logs.

```bash
aws sso login --profile mi-perfil
export AWS_PROFILE=mi-perfil
```

## 1. Crear el backend del state (una sola vez por cuenta)

El bucket del state se crea con CloudFormation para resolver el problema del "huevo y la gallina": Terraform necesita el bucket antes de poder guardar su propio state.

```bash
aws cloudformation deploy \
  --template-file bootstrap/terraform-backend.yaml \
  --stack-name terraform-backend \
  --region us-east-1

aws cloudformation describe-stacks \
  --stack-name terraform-backend \
  --region us-east-1 \
  --query "Stacks[0].Outputs[?OutputKey=='BucketName'].OutputValue" \
  --output text
```

El bucket queda con versionado, cifrado SSE-S3, acceso público bloqueado, solo HTTPS y limpieza automática de versiones antiguas. Tiene `DeletionPolicy: Retain`: si borras el stack, el bucket (y tu state) se conservan.

## 2. Desplegar la arquitectura

Hay dos alternativas: desde tu máquina o con el pipeline. Ambas usan el mismo bucket y la misma key del state, así que puedes pasar de una a otra.

### Opción A: desde local

```bash
terraform init \
  -backend-config="bucket=<bucket-del-state>" \
  -backend-config="key=demo/infra/dev/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="encrypt=true" \
  -backend-config="use_lockfile=true"

terraform plan -var="owner=<tu-nombre>" -out=tfplan
terraform apply tfplan
```

### Opción B: con el pipeline (CodePipeline)

Necesitas una conexión a GitHub en estado `AVAILABLE` (Developer Tools → Settings → Connections). El stack crea el pipeline, sus roles y la configuración en Parameter Store:

```bash
aws cloudformation deploy \
  --template-file bootstrap/terraform-pipeline.yaml \
  --stack-name pipeline-demo \
  --region us-east-1 \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    ConnectionArn=<arn-de-la-conexion> \
    FullRepositoryId=<owner>/<repo> \
    StateBucketName=<bucket-del-state> \
    Owner=<tu-nombre>
```

Cada push a `main` ejecuta `terraform plan`, espera una aprobación manual y luego aplica ese mismo plan.

### Probar

Abre el output `url` (frontend, por HTTP). La API queda en el output `api_url`; con el pipeline, ambos aparecen al final de los logs de la fase Deploy.

```bash
curl -X POST "$(terraform output -raw api_url)/api/visits"
curl "$(terraform output -raw api_url)/api/visits"
```

## 3. Validaciones de calidad y seguridad

```bash
terraform fmt -check -recursive
checkov -d . --config-file .checkov.yaml
```

`.checkov.yaml` documenta cada excepción y por qué se acepta en un ambiente de demo. En producción, revisa esa lista.

## 4. Destruir todo

```bash
terraform destroy -var="owner=<tu-nombre>"
```

`force_destroy = true` en el bucket del frontend permite borrarlo con sus objetos y versiones. **No uses ese valor en producción.**

El bucket del state **no** se borra con `terraform destroy` ni al borrar el stack de CloudFormation. Si ya no lo necesitas, vacíalo (incluidas todas sus versiones) y bórralo manualmente.

## Costos

Con poco tráfico, el costo de la demo es prácticamente US$0: todos los servicios son de pago por uso y no hay NAT Gateway, balanceadores ni bases de datos con costo fijo. Point-in-time recovery de DynamoDB queda activo (default del módulo) y su costo depende del tamaño de la tabla, que aquí es mínimo. Configura una alerta de **AWS Budgets** y destruye la infraestructura al terminar.

## Troubleshooting

**El pipeline no arranca con un push.** Suele pasar cuando la app de AWS está _autorizada_ en GitHub, pero no _instalada_ (sin instalación no hay webhooks):

1. En GitHub → Settings → Applications → **Installed GitHub Apps**, confirma que "AWS Connector for GitHub" tiene acceso al repositorio. Si no aparece, instálala desde <https://github.com/apps/aws-connector-for-github>.
2. Crea de nuevo la conexión en AWS, eligiendo esa instalación antes de dar "Connect".
3. Actualiza el stack del pipeline con el ARN nuevo (`ConnectionArn`) y haz un push de prueba.

**"Dynamic import failed" al crear la conexión.** Es un error de la consola de AWS al cargar la página. Reintenta en una ventana de incógnito sin extensiones o en otro navegador.
