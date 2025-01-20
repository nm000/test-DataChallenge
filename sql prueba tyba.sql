/* CREACIÓN DE LAS 4 TABLAS */

CREATE TABLE Producto (
    productoID SERIAL PRIMARY KEY,
    descripcion VARCHAR(255) NOT NULL,
    tasaRetorno FLOAT NOT NULL
);

CREATE TABLE Cliente (
    clienteID SERIAL PRIMARY KEY,
	nombre VARCHAR(255) NOT NULL,
	apellido VARCHAR(255) NOT NULL,
	correo VARCHAR(255) NOT NULL,
	aums FLOAT DEFAULT 0
);

CREATE TABLE Suscripcion (
    suscripcionID SERIAL PRIMARY KEY,
	clienteID INT REFERENCES Cliente(clienteID) ON DELETE CASCADE,
    productoID INT REFERENCES Producto(productoID) ON DELETE CASCADE,
	valor FLOAT NOT NULL DEFAULT 0,
    fechaInicio DATE NOT NULL,
    fechaFin DATE
);

CREATE TABLE Transaccion (
	transaccionID SERIAL PRIMARY KEY,
	clienteID INT REFERENCES Cliente(clienteID) ON DELETE CASCADE,
	suscripcionID INT REFERENCES Suscripcion(suscripcionID) ON DELETE CASCADE,
	monto FLOAT NOT NULL,
	fecha DATE NOT NULL
);

/* INGESTA DE LAS TABLAS */

DO $$ -- Creación aleatoria de clientes
DECLARE
    nombre_array TEXT[] := ARRAY['Juan', 'María', 'Carlos', 'Pedro', 'Laura', 'Ana', 'Lucía', 'Javier', 'Marta', 'Sofía', 'Ricardo', 'David', 'Isabel', 'Miguel', 'Beatriz']; 
    apellido_array TEXT[] := ARRAY['Pérez', 'López', 'García', 'Gómez', 'Ramírez', 'Martínez', 'González', 'Hernández', 'Castro', 'Alonso', 'Moreno', 'Sánchez', 'Torres'];
    cliente RECORD;
    id_cliente INT := 1;
    nombre_random TEXT;
    apellido_random TEXT;
BEGIN
    FOR i IN 1..250 LOOP
        
        nombre_random := nombre_array[ceil(random() * array_length(nombre_array, 1))];
        apellido_random := apellido_array[ceil(random() * array_length(apellido_array, 1))];
        
        INSERT INTO Cliente (nombre, apellido, correo)
        VALUES (
            nombre_random,
            apellido_random,
            CONCAT(nombre_random, '.', apellido_random, '.', id_cliente, '@gmail.com')
        );
        
        id_cliente := id_cliente + 1;
    END LOOP;
END $$;


INSERT INTO Producto( -- Creación de 3 productos 
	descripcion, tasaRetorno
) VALUES ('tyba Pocket', 0.01),
	('FPV Digital', 0.007),
	('CDT', 0.009);

CREATE OR REPLACE FUNCTION actualizar_despues_de_transaccion() -- Función para actualizar tanto los montos de suscripciones, como los AUMs de los clientes luego de una transacción.
	RETURNS TRIGGER AS $$
	DECLARE
	    monto_temp FLOAT;
BEGIN
	    IF EXISTS ( 
	        SELECT 1 
	        FROM Suscripcion 
	        WHERE suscripcionID = NEW.suscripcionID 
	        AND fechaFin IS NULL
	        AND valor = 0
	    ) THEN
	        -- Si la suscripción ya existe y tiene monto 0 (es la primera suscripción), se actualiza el valor al del monto de la transaccion.
	        UPDATE Suscripcion
	        SET valor = NEW.Monto
	        WHERE suscripcionID = NEW.suscripcionID
	        AND fechaFin IS NULL
	        AND valor = 0; 
	
	    -- Si la suscripción ya tiene un monto distinto de 0, se va a hacer un aporte o retiro a la suscripción y va a haber un cambio del valor invertido en la misma.
	    ELSIF EXISTS (
	        SELECT 1 
	        FROM Suscripcion 
	        WHERE suscripcionID = NEW.suscripcionID 
	        AND fechaFin IS NULL
	        AND valor > 0 
	    ) THEN
	        -- Se actualiza la fecha fin de la suscripción vigente, ya que el monto cambiará.
	        UPDATE Suscripcion
	        SET fechaFin = NEW.fecha
	        WHERE suscripcionID = NEW.suscripcionID 
	        AND fechaFin IS NULL;
	
			SELECT Suscripcion.valor INTO monto_temp FROM Suscripcion WHERE suscripcionID = NEW.suscripcionID;
			monto_temp := monto_temp + NEW.monto;
			
	        -- Se crea la nueva sucripción con el nuevo monto y nueva fecha de inicio.
	        INSERT INTO Suscripcion (clienteID, productoID, fechaInicio, valor)
	        VALUES (
	            NEW.clienteID,
	            (SELECT productoID FROM Suscripcion WHERE suscripcionID = NEW.suscripcionID),
	            NEW.fecha,
	            monto_temp
	        );
	    END IF;
	
	    -- Se calcula el AUMs del cliente sumando todas sus sucripciones activas (fechafin con valor null)
	    UPDATE Cliente
	    SET aums = (
	        SELECT SUM(valor)
	        FROM Suscripcion
	        WHERE Suscripcion.clienteID = NEW.clienteID
	        AND Suscripcion.fechaFin IS NULL
	    )
	    WHERE clienteID = NEW.clienteID;
	
	    RETURN NEW;
	END;
	$$ LANGUAGE plpgsql;
	
	CREATE OR REPLACE FUNCTION existe_suscripcion(cliente_id INT, producto_id INT) -- Se valida que exista una suscripcion para un cliente con un producto.
	RETURNS BOOLEAN AS $$
	DECLARE
	    resultado BOOLEAN;
	BEGIN
	
	    SELECT EXISTS (
	        SELECT 1
	        FROM Suscripcion
	        WHERE clienteID = cliente_id
	        AND productoID = producto_id
	        AND fechaFin IS NULL
	    ) INTO resultado;
	
	    RETURN resultado;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trigger_actualizar_despues_transaccion -- Trigger para actualizar montos justo después de insertar transacciones
AFTER INSERT ON Transaccion
FOR EACH ROW
EXECUTE FUNCTION actualizar_despues_de_transaccion();

/* INGESTA DE DATOS DE PRUEBA EN TABLAS */

DO $$ 
DECLARE 
    i INT; 
	mes INT;
    random_product_id INT; 
    suscripcion_id INT; 
BEGIN 
    FOR i IN 1..250 LOOP 
        mes := floor(random() * 12 + 1);

        IF mes < 10 THEN
            mes := concat('0', mes); 
        END IF;
        random_product_id := floor(random() * 3) + 1;

        IF NOT EXISTS (
            SELECT 1
            FROM Suscripcion
            WHERE clienteID = i
            AND productoID = random_product_id
            AND fechaFin IS NULL
        ) THEN
            -- De no tener el cliente una suscripción para ese producto, se le crea.
            INSERT INTO Suscripcion(clienteID, productoID, fechaInicio) 
            VALUES (i, random_product_id, CAST(concat('2023-', mes, '-01') AS DATE));
        END IF;

        -- Obtener el SuscripcionID de la suscripción recién insertada o existente.
        SELECT SuscripcionID INTO suscripcion_id
        FROM Suscripcion 
        WHERE clienteID = i
        AND productoID = random_product_id
        AND fechaFin IS NULL
        LIMIT 1;

        IF suscripcion_id IS NOT NULL THEN
            INSERT INTO Transaccion(clienteID, suscripcionID, monto, fecha) 
            VALUES (
                i, 
                suscripcion_id,
                (floor(random() * (1000000 - 5000000 + 1)) + 5000000),
                CAST(concat('2023-', mes, '-01') AS DATE)
            );
        END IF;
    END LOOP;
END $$;

/* INGESTA DE ESCENARIOS EN LOS QUE UN CLIENTE PUEDE HACER APORTES O RETIROS A ALGUNA DE SUS SUSCRIPCIONES ASOCIADAS A LOS PRODUCTOS */

DO $$ 
DECLARE 
    i INT; 
    random_mes INT;
    random_año INT;
    random_product_id INT; 
    suscripcion_id INT; 
	suscripcion_valor INT;
	transaccion_monto INT;
BEGIN 
    FOR i IN 1..200 LOOP 
            random_mes := FLOOR(RANDOM() * 12) + 1;
            IF random_mes < 10 THEN 
                random_mes := concat('0', random_mes); 
            END IF; 
        random_año := 2024;
        random_product_id := FLOOR(RANDOM() * 3) + 1;

        IF NOT EXISTS (
            SELECT 1
            FROM Suscripcion
            WHERE clienteID = i
            AND productoID = random_product_id
            AND fechaFin IS NULL
        ) THEN
            -- Si el cliente no tiene una suscripción al producto aleatorio, se le crea.
            INSERT INTO Suscripcion(clienteID, productoID, fechaInicio) 
            VALUES (i, random_product_id, CAST(concat(random_año, '-', random_mes, '-01') AS DATE));
        END IF;

        SELECT SuscripcionID INTO suscripcion_id
        FROM Suscripcion 
        WHERE clienteID = i
        AND productoID = random_product_id
        AND fechaFin IS NULL
        LIMIT 1;

		-- Generar valor aleatorio para el abono o retiro.
		SELECT Suscripcion.valor INTO suscripcion_valor FROM Suscripcion WHERE Suscripcion.suscripcionID=suscripcion_id;
		transaccion_monto := FLOOR(RANDOM() * (1000000 - (-1000000) + 1)) + (-1000000);

        IF suscripcion_valor + transaccion_monto < 0 THEN
            transaccion_monto := -suscripcion_valor + 100000 ; -- Evitar que la suscripción quede negativa.
        END IF;

	            INSERT INTO Transaccion(clienteID, suscripcionID, monto, fecha) 
	            VALUES (
	                i, 
	                suscripcion_id,
	                transaccion_monto,
	                CAST(concat(random_año, '-', random_mes, '-01') AS DATE)
	            );
    END LOOP;
END $$;

/* CREACIÓN DE TABLAS TEMPORALES PARA EL CÁLCULO DE LTV */

CREATE TEMP TABLE temp_flujo_caja_cliente (
	clienteID INT,
    mes INT,
    flujoCaja NUMERIC(20, 10)
);

CREATE TEMP TABLE temp_vpn_cliente (
    clienteID INT,
    vpn NUMERIC(20, 10)
);

/* CÁLCULO DEL FLUJO DE CAJA PARA LOS 72 MESES PLANTEADOS */

CREATE OR REPLACE FUNCTION calcular_flujo_de_caja_por_cliente()
RETURNS VOID AS $$
DECLARE
    cliente RECORD;
    mes INT;
    flujo_caja NUMERIC(20, 8);
    tasa_diaria NUMERIC(20, 8) := (1 + 0.005) ^ (1.0 / 365.0) - 1; --  Conversión de la comisión acentuada en 0.005% EA, capitalizada diariamente.
    aums_previo NUMERIC(20, 8);
    aums_actual NUMERIC(20, 8);
    meses_sub INT;
BEGIN
    FOR cliente IN 
        SELECT clienteID, aums FROM Cliente
    LOOP
        -- Obtener los meses para los que duró una suscripción con x valor.
        SELECT valor, 
               COALESCE(DATE_PART('year', AGE(LEAD(fechaInicio) OVER (PARTITION BY clienteID ORDER BY fechaInicio), fechaInicio)) * 12 +
                        DATE_PART('month', AGE(LEAD(fechaInicio) OVER (PARTITION BY clienteID ORDER BY fechaInicio), fechaInicio)), 0)
        INTO aums_previo, meses_sub
        FROM Suscripcion
        WHERE clienteID = cliente.clienteID
        ORDER BY fechaInicio
        LIMIT 1;
        
        -- Iterar sobre los meses de la suscripción no vigente.
        FOR mes IN 1..meses_sub LOOP
            flujo_caja := aums_previo * tasa_diaria * 30 - 100;
            INSERT INTO temp_flujo_caja_cliente (clienteID, mes, flujoCaja)
            VALUES (cliente.clienteID, mes, flujo_caja);
        END LOOP;

        -- Para los siguientes meses, considera las otras suscripciones si existen
        FOR mes IN meses_sub+1..72 LOOP
            flujo_caja := cliente.aums * tasa_diaria * 30 - 100;
            INSERT INTO temp_flujo_caja_cliente (clienteID, mes, flujoCaja)
            VALUES (cliente.clienteID, mes, flujo_caja);
        END LOOP;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

SELECT calcular_flujo_de_caja_por_cliente(); -- Ejecuta la función de cálculo de flujo de caja

/* CÁLCULO DEL VPN POR CLIENTE */

CREATE OR REPLACE FUNCTION calcular_vpn_por_cliente()
RETURNS VOID AS $$
DECLARE
    cliente RECORD;
    controlador_mes INT;
    flujo_caja NUMERIC(20, 8);
    vpn NUMERIC(20, 8);
    tasa_mensual NUMERIC(20, 8) := (1 + 0.15) ^ (1.0 / 12) - 1; -- Conversión de la tasa de descuento en 15% EA a Efectivo Mensual
	inversion NUMERIC(20,8);
BEGIN
    
    FOR cliente IN SELECT clienteID FROM Cliente LOOP
        vpn := 0;
        
        FOR controlador_mes IN 1..72 LOOP
            SELECT FlujoCaja
            INTO flujo_caja
            FROM temp_flujo_caja_cliente
            WHERE temp_flujo_caja_cliente.clienteID = cliente.clienteID 
              AND temp_flujo_caja_cliente.mes = controlador_mes;
              
            vpn := vpn + (flujo_caja / ((1.0 + tasa_mensual) ^ controlador_mes));
        END LOOP;

		vpn := vpn - 100;

        INSERT INTO temp_vpn_cliente (clienteID, vpn)
        VALUES (cliente.clienteID, vpn);
    END LOOP;
END;
$$ LANGUAGE plpgsql;

SELECT calcular_vpn_por_cliente(); -- Ejecuta la función de cálculo de VPN


WITH Cosecha AS ( -- Calcular los clientes por cosecha dependiendo de la fecha más antigua de suscripción que tengan (independientemente de si sigue vigente la misma)
    SELECT DISTINCT ON (Suscripcion.clienteID) 
        Suscripcion.clienteID, 
        MIN(Suscripcion.fechaInicio) OVER (PARTITION BY Suscripcion.clienteID ORDER BY Suscripcion.fechaInicio) AS CosechaID,
        temp_vpn_cliente.vpn
    FROM Suscripcion 
    JOIN temp_vpn_cliente ON temp_vpn_cliente.clienteID = Suscripcion.clienteID
)

SELECT Cosecha.cosechaID AS "Cosecha", 
    COUNT(DISTINCT Cosecha.clienteID) AS "Numero de clientes en la cosecha",
    CONCAT('$',ROUND(AVG(Cosecha.vpn)/3900,0),' USD') AS "LTV estimado por cliente" -- Cálculo del promedio de los VPN por cliente dentro de la cosecha y conversión del LTV de COP a USD
FROM Cosecha
GROUP BY Cosecha.cosechaID
ORDER BY Cosecha.cosechaID ASC;


	
