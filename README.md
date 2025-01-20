# Prueba Técnica SQL – Data Analyst para Tyba

Este repositorio contiene la solución a la prueba técnica SQL para el cargo de Data Analyst en Tyba. La solución incluye el diseño del esquema de base de datos, la generación de datos representativos y el cálculo del Lifetime Value (LTV) de los clientes agrupados por cosechas mensuales.

## Descripción General
La prueba consiste en calcular el LTV para los clientes utilizando el enfoque de Valor Presente Neto (VPN) durante un horizonte de 72 meses. La base de datos se diseñó siguiendo principios de normalización y contiene información sobre clientes, productos financieros, suscripciones y transacciones.

## Esquema de la Base de Datos
El esquema incluye las siguientes tablas principales:

1. **Producto**: Información sobre los productos financieros ofrecidos.
2. **Cliente**: Datos personales de los clientes y sus activos bajo administración (AUMs).
3. **Suscripción**: Registro de inversiones de los clientes en productos específicos.
4. **Transacción**: Movimientos financieros relacionados con las suscripciones.

## Componentes Clave

### 1. Creación del Esquema
El esquema de base de datos se crea con scripts SQL, que incluyen las tablas, relaciones, índices y triggers para asegurar consistencia e integridad.

### 2. Generación de Datos
Se generaron datos de prueba representativos:
- **Clientes**: 250 registros con nombres y correos generados aleatoriamente.
- **Productos**: Tres productos financieros con tasas de retorno entre 0.5% EA y 1% EA.
- **Suscripciones y Transacciones**: Datos generados dinámicamente con montos ajustados a una distribución normal.

### 3. Cálculo del LTV
El LTV se calcula en tres pasos principales:
1. Proyección de flujos de caja mensuales por cliente considerando comisiones diarias.
2. Cálculo del VPN para cada cliente con una tasa de descuento del 15% EA.
3. Agrupación de clientes por cosecha (mes de su primera inversión) y cálculo del LTV promedio por cliente.

## Estructura del Repositorio
- `prueba.sql`: Script SQL completo que incluye la creación de tablas, generación de datos y cálculo del LTV.
- `README.md`: Este archivo de documentación.

## Ejecución
1. Instalar PostgreSQL y configurar una base de datos.
2. Ejecutar el script `prueba.sql` en el entorno de PostgreSQL.
3. Consultar los resultados del cálculo del LTV para las cosechas del año 2023.

## Resultados Esperados
La consulta final devuelve un resumen con:
- **Cosecha**: Mes de la primera inversión del cliente.
- **Número de clientes**: Total de clientes por cosecha.
- **LTV estimado por cliente**: Valor promedio del VPN convertido a USD.
