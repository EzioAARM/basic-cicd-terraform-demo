// Contador de visitas: GET lo consulta, POST lo incrementa.
// El AWS SDK v3 ya viene incluido en el runtime de Node.js de Lambda.
import {
  DynamoDBClient,
  GetItemCommand,
  UpdateItemCommand,
} from "@aws-sdk/client-dynamodb";

const db = new DynamoDBClient({});
const TABLE = process.env.TABLE_NAME;
const MESSAGE = process.env.MESSAGE;
const ALLOWED_ORIGIN = process.env.ALLOWED_ORIGIN;
const KEY = { pk: { S: "visits" } };

const json = (statusCode, body) => ({
  statusCode,
  headers: {
    "content-type": "application/json",
    "cache-control": "no-store",
    // El frontend (S3) está en otro dominio que la API.
    "access-control-allow-origin": ALLOWED_ORIGIN,
  },
  body: JSON.stringify(body),
});

export const handler = async (event) => {
  // REST API (payload 1.0) usa httpMethod; HTTP API (payload 2.0), requestContext.http.method.
  const method = event.httpMethod ?? event.requestContext?.http?.method;

  try {
    if (method === "POST") {
      const res = await db.send(
        new UpdateItemCommand({
          TableName: TABLE,
          Key: KEY,
          UpdateExpression: "ADD #count :one",
          ExpressionAttributeNames: { "#count": "count" },
          ExpressionAttributeValues: { ":one": { N: "1" } },
          ReturnValues: "UPDATED_NEW",
        })
      );
      return json(200, { message: MESSAGE, visits: Number(res.Attributes.count.N) });
    }

    const res = await db.send(new GetItemCommand({ TableName: TABLE, Key: KEY }));
    return json(200, { message: MESSAGE, visits: Number(res.Item?.count?.N ?? 0) });
  } catch (err) {
    console.error(JSON.stringify({ error: err.name, detail: err.message }));
    return json(500, { error: "Error interno" });
  }
};
