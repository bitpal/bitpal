%{
    title: "API Reference"
}
---

BitPal's API comes in two flavors:

- [A REST API](#REST) for initializing, updating and retrieving invoices and other resources.
- [A websocket API](#Websockets) for recieving updates in real-time.


# REST

BitPal has standard [REST][rest-wiki] endpoints with human-friendly JSON-encoded results and uses standard HTTP [response status codes][http-status] and [authentication][http-auth].

<aside class="notice">
  All API requests uses placeholders for resource ids, the server ip and API keys. You'll neet to replace them with your own to get the examples to work.
</aside>

[rest-wiki]: https://developer.mozilla.org/en-US/docs/Glossary/REST 
[http-status]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Status
[http-auth]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Authentication#basic_authentication_scheme 


## Authentication

> Authenticated request

> ~~~sh
> # The trailing colon ignores the password
> curl https://api.<your-ip>/v1/invoices/<invoice-id> \
>   -u <token>:
> ~~~

Requests are authenticated using [API keys][]. To use the API you need to generate a key and they will look something like this:

```
SFMyNTY.g2gDYQFuBgDWhevRegFiAAFRgA.fuiV-GbJoBUmKaSS5PW776HyeFh30-L9pgvn7wuQWKk
```

Authentication is sent using [HTTP Basic Auth][http-auth]. Provide the API key as the username and no password (the password will be ignored).

[API keys]: #


## Errors

> 400 - Bad Request             : The request was unacceptable, often due to missing a required parameter.
> 401 - Unauthorized            : No valid API key provided.
> 402 - Request Failed          : The parameters were valid but the request failed.
> 403 - Forbidden               : The API key doesn't have permissions to perform the request.
> 404 - Not Found               : The requested resource doesn't exist.
> 500 - Internal server error   : Something went wrong on the server.
{: parser="http-status-code"}


## Invoices

~~~
  POST /v1/invoices
   GET /v1/invoices/:id
  POST /v1/invoices/:id
DELETE /v1/invoices/:id
  POST /v1/invoices/:id/finalize
  POST /v1/invoices/:id/pay
  POST /v1/invoices/:id/void
   GET /v1/invoices
~~~
{: parser="endpoints"}

### Retrieve an invoice

~~~sh
$ curl https://api.localhost:4000/v1/invoices/<some-id> \
    -u <your-token>:
~~~
{: parser="endpoint" header="GET /v1/invoices/:id"}

~~~json
{
    "id" => id,
    "address" => nil,
    "amount" => "1.2",
    "currency" => "BCH",
    "fiat_amount" => "2.4",
    "fiat_currency" => "USD",
    "required_confirmations" => 0,
    "status" => "draft",
    "email" => "test@bitpal.dev",
    "description" => "My awesome invoice",
    "pos_data" => {
        "some" => "data",
        "other" => {
            "even_more" => 0
        }
    }
}
~~~
{: parser="aside" header="RESPONSE"}

## Transactions

~~~
   GET /v1/transactions/:txid
   GET /v1/transactions
~~~
{: parser="endpoints"}

## Exchange rates

~~~
   GET /v1/rates/:basecurrency
   GET /v1/rates/:basecurrency/:currency
~~~
{: parser="endpoints"}

## Currencies

~~~
   GET /v1/rates/:currencies
   GET /v1/rates/:currencies/:id
~~~
{: parser="endpoints"}

# Websockets

Use `wscat` to try out websockets (or maybe a non-npm based thing?)
Rust alternative: https://github.com/hwchen/manx-rs

https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-how-to-call-websocket-api-wscat.html
https://github.com/websockets/wscat

## Authentication

## Channels

> Channels

> ~~~
> invoice:<invoice_id>
> exchange_rate:<basecurrency>-<currency>
> ~~~

## Invoice events

> Channel

> ~~~
>invoice:<invoice_id>
> ~~~

### Processing

### Underpaid

### Uncollectible

### Paid

## Exchange rates

> Channel

> ~~~
> exchange_rate:<basecurrency>-<currency>
> ~~~

### Request

### Rate
