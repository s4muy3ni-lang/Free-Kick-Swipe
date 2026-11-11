# Pagos con dinero real — comparación de proveedores (sin cobros activados)

Estado: **no se cobra nada.** El juego tiene la estructura lista: catálogo de productos (`store_products`, inactivos),
registro de compras (`purchases`, con `provider_ref` único para no entregar dos veces), entrega SOLO por el servidor
(`grant_purchase`, que solo puede llamar el servicio con la service key) y la tienda con monedas virtuales. Falta elegir
proveedor y escribir el webhook (Edge Function de Supabase).

Las cifras de abajo salen de fuentes públicas consultadas el 2026-11-11. Varias son secundarias y no coinciden entre sí.
**Hay que verificarlas en la página oficial de cada proveedor antes de decidir.**

## La regla que manda: dónde se vende

| Canal | Qué exige | Consecuencia |
|---|---|---|
| **Android (Google Play)** | Los bienes digitales dentro de una app de Play se cobran con **Google Play Billing**, o con alternativas solo donde Google lo permite. | Pase, monedas y cosméticos vendidos dentro de la APK de Play van por Play Billing. Mercado Pago no se puede usar ahí para bienes digitales. |
| **Web (versión Bolt)** | Libre. | Mercado Pago para ARS y un «merchant of record» para el exterior. |
| **APK fuera de Play** | Libre. | Mercado Pago. |

## Proveedores

| Proveedor | Para qué | Costo (según las fuentes, a verificar) | ARS | Notas |
|---|---|---|---|---|
| **Google Play Billing** | Compras dentro de la app de Android | Tarifa de servicio: 15 % sobre el primer millón de USD anual (programa del 15 %). Google anunció un esquema nuevo desde 10 % en algunos mercados (EE. UU., EEE y Reino Unido primero), con cargo de facturación aparte. No hay dato específico de Argentina. | Sí: Play cobra al usuario en su moneda. | Obligatorio para lo digital en Play. Suscripciones y reembolsos los maneja Play. Se verifica con la API de Play Developer desde el servidor. |
| **Mercado Pago (Checkout Pro / API)** | Web y APK fuera de Play, Argentina | Escala según el plazo de acreditación: 6,29 % + IVA al instante … 1,49 % + IVA a 35 días. Otra fuente indica 2,99 % + IVA estándar. Puede haber retenciones provinciales. | Nativo. | Webhooks de notificación; reembolsos por API; cuotas. Ideal para jugadores argentinos en la web. |
| **Paddle** (merchant of record) | Web internacional | 5 % + 0,50 USD por transacción (plan inicial). | No como moneda de cobro local garantizada. | Se ocupa de impuestos y facturación en el exterior. Falta confirmar que acepta vendedores de Argentina. |
| **Lemon Squeezy / Stripe Managed Payments** (merchant of record) | Web internacional | Cifras en conflicto: 5 % + 0,50 USD o tarifa de Stripe + 3,5 %. | No. | Ahora pertenece a Stripe. Hay que confirmar si acepta vendedores argentinos (Stripe no abre cuentas en Argentina). |

## Recomendación (para decidir, no implementada)

1. **Android en Play:** Google Play Billing para el pase de temporada, las monedas y los cosméticos, con verificación
   del token de compra en el servidor (Edge Function) y entrega con `grant_purchase`.
2. **Web:**
   - Mercado Pago para pagos en ARS;
   - un merchant of record (Paddle) para el resto del mundo, si acepta vendedores de Argentina.
3. **Precios:**
   - precio de referencia en USD (`store_products.price_usd_cents`) y precio local por moneda (`prices`, p. ej. ARS);
   - en Play, los precios los fija la consola de Play por país.

## Flujo seguro previsto (igual para todos)

1. El cliente pide comprar → el servidor crea `purchases(status = 'pending')` y la preferencia o el pedido en el proveedor.
2. El proveedor confirma por **webhook** → la Edge Function valida la firma y el monto contra el proveedor, y marca
   `paid`.
3. `grant_purchase(id)` entrega una sola vez (si ya está `granted`, no hace nada; `provider_ref` es único).
4. **Reembolso** → webhook → `status = 'refunded'` y se retira lo entregado (pendiente de definir la política).
5. **Nunca** se guardan datos de tarjeta: los maneja el proveedor.

## Fuentes consultadas

- Mercado Pago: [iProfesional](https://www.iprofesional.com/tecnologia/386153-mercado-pago-que-debes-saber-sobre-comisiones-plazos-y-montos),
  [calculadora 2026](https://app.spomsolutions.com/herramientas/comisiones-mercado-pago-2026),
  [Tiendanube](https://ayuda.tiendanube.com/es_AR/122921-mercado-pago/preguntas-frecuentes-sobre-mercado-pago),
  [guía de pasarelas](https://www.guiadesoftware.com/blog/mejor-pasarela-pago-argentina).
- Google Play: [tarifas de servicio (Google)](https://support.google.com/googleplay/android-developer/answer/112622?hl=en),
  [blog de Android Developers](https://android-developers.googleblog.com/2026/06/play-expanded-billing.html?hl=be),
  [PocketGamer.biz](https://www.pocketgamer.biz/google-play-expands-billing-options-and-lowers-fees-for-developers/).
- Paddle y Lemon Squeezy: [comparación de tarifas](https://dev.to/jettfu/stripe-vs-paddle-vs-lemon-squeezy-fee-comparison-2026-2c77),
  [Paddle vs Lemon Squeezy](https://resources.rework.com/tools/billing-revenue/paddle-vs-lemon-squeezy),
  [merchant of record 2026](https://alexcloudstar.com/blog/merchant-of-record-indie-saas-2026/),
  [DevToolLab](https://devtoollab.com/blog/best-merchant-of-record-platforms).
