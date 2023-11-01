-- NOMBRE: RODRIGO
-- APELLIDOS: GARCÍA JIMÉNEZ
-- GMAIL: alu0101154473@ull.edu.es
-- ASIGNATURA: ADMINISTRACIÓN Y DISEÑO DE BASE DE DATOS
-- CURSO: 4º
-- FECHA: 31-10-2023

-- Creación de la tabla CLIENTE
CREATE TABLE CLIENTE (
    -- DNI se declara como varchar 
    dni_cliente VARCHAR(8) PRIMARY KEY,
    CHECK (dni_cliente IS NOT NULL AND dni_cliente NOT LIKE '%[^0-9]%'),
    Nombre VARCHAR(50) NOT NULL,
    Apellidos VARCHAR(50) NOT NULL,
    -- https://voipstudio.es/blog/que-es-el-formato-e-164-y-como-usarlo-correctamente/#:~:text=El%20E.,%C3%BAnico%20en%20todo%20el%20mundo.
    Tlf VARCHAR(15) NOT NULL,
    Direccion VARCHAR(100)
);

-- Creación de la tabla TAJINASTE+
CREATE TABLE TAJINASTEPlus (
    idTajinastePlus VARCHAR(8) PRIMARY KEY,
    CHECK (idTajinastePlus IS NOT NULL AND idTajinastePlus NOT LIKE '%[^0-9]%'),
    -- Se entiende por bonificación una cantidad de € sin contar los céntimos
    -- y sin valor máximo.
    bonif INT DEFAULT 0,
    CHECK (bonif >= 0),
    FOREIGN KEY (idTajinastePlus) REFERENCES CLIENTE(dni_cliente)
);

-- Creación de la tabla EMPLEADO
CREATE TABLE EMPLEADO (
    idEMPLEADO INT PRIMARY KEY,
    Nombre VARCHAR(50) NOT NULL,
    Apellidos VARCHAR(50) NOT NULL,
    Tlf VARCHAR(15) NOT NULL,
    Direccion VARCHAR(255) NOT NULL,
    -- Aunque DNI no sea clave primaria, ha de ser único
    DNI VARCHAR(8) UNIQUE NOT NULL,
    -- Comprobar que el DNI contiene el tamaño adecuado.
    CHECK (LENGTH(DNI) = 8),
    productividad DECIMAL(5, 2) DEFAULT 0.0,
    CHECK (productividad >= 0.00 AND productividad <= 100.00)
);

-- Creación de la tabla VIVERO
CREATE TABLE VIVERO (
    idVivero INT PRIMARY KEY,
    nombreVivero VARCHAR(50)
);

-- Creación de la tabla ZONA
CREATE TABLE ZONA (
    idZona INT PRIMARY KEY,
    nombreZona VARCHAR(50) NOT NULL,
    idVivero INT,
    latitud DECIMAL(10, 6) NOT NULL,
    longitud DECIMAL(10, 6) NOT NULL,
    productividad DECIMAL(5, 2) DEFAULT 0.0,
    CHECK (productividad >= 0.00 AND productividad <= 100.00),
    FOREIGN KEY (idVivero) REFERENCES VIVERO(idVivero)
);

-- Creación de la tabla TAREA
CREATE TABLE TAREA (
    idTarea INT PRIMARY KEY,
    idZona INT,
    NombreTarea VARCHAR(50) NOT NULL,
    Descripcion VARCHAR(255),
    FOREIGN KEY (idZona) REFERENCES ZONA(idZona)
);

-- Creación de la tabla PRODUCTO
CREATE TABLE PRODUCTO (
    idProducto INT PRIMARY KEY,
    NombreProducto VARCHAR(50) NOT NULL,
    Descripcion VARCHAR(255),
    Precio DECIMAL(10, 2) NOT NULL
);

-- Creación de la tabla PEDIDO
CREATE TABLE PEDIDO (
    idEmpleado INT NOT NULL,
    idProducto INT,
    fechaCompra DATE,
    dni_cliente VARCHAR(8),
    CHECK (dni_cliente IS NOT NULL AND dni_cliente NOT LIKE '%[^0-9]%'),
    PRIMARY KEY (idProducto, fechaCompra, dni_cliente),
    FOREIGN KEY (idEmpleado) REFERENCES EMPLEADO(idEMPLEADO),
    FOREIGN KEY (idProducto) REFERENCES PRODUCTO(idProducto),
    FOREIGN KEY (dni_cliente) REFERENCES TAJINASTEPlus(idTajinastePlus)
);

-- Creación de la tabla ASIGNACION_TAREAS
-- Se crea esta tabla porque una tarea puede no estar asignada 
-- a una persona
CREATE TABLE  ASIGNACION_TAREAS(
    idEmpleado INT,
    idTarea INT,
    FIni DATE NOT NULL,
    FFin DATE,
    -- Empleado puede hacer varias tareas y viceversa, 
    -- y también puede hacer una tarea en varios periodos
    PRIMARY KEY (idEmpleado, idTarea),
    FOREIGN KEY (idEmpleado) REFERENCES EMPLEADO(idEMPLEADO),
    FOREIGN KEY (idTarea) REFERENCES TAREA(idTarea),
    CHECK (FFin >= FIni) -- Restricción para que FFin sea mayor/igual(tarea un día) que FIni
);

-- Creación de la tabla DISPONIBILIDAD
CREATE TABLE DISPONIBILIDAD_PRODUCTO (
    idProducto INT,
    idZona INT,
    unidadesDisponibles INT DEFAULT 0,
    CHECK (unidadesDisponibles >= 0),
    PRIMARY KEY (idProducto, idZona),
    FOREIGN KEY (idProducto) REFERENCES PRODUCTO(idProducto),
    FOREIGN KEY (idZona) REFERENCES ZONA(idZona)
);

-- DISPARADORES
-- Funcion que comprueba que solo hay una fecha de comienzo por cada empleado
CREATE OR REPLACE FUNCTION check_unique_employee_start_date()
RETURNS TRIGGER AS $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM ASIGNACION_TAREAS AT
    WHERE AT.idEmpleado = NEW.idEmpleado
    AND AT.FIni = NEW.FIni
  ) THEN
    RAISE EXCEPTION 'Un empleado solo puede tener una fecha de comienzo única.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
-- Disparador que lo ejecuta
CREATE TRIGGER check_employee_start_date
BEFORE INSERT ON ASIGNACION_TAREAS
FOR EACH ROW
EXECUTE FUNCTION check_unique_employee_start_date();

-- Funcion que comprueba que una fecha de inicio no está entre dos fechas de un periodo
CREATE OR REPLACE FUNCTION check_employee_start_date()
RETURNS TRIGGER AS $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM ASIGNACION_TAREAS
    WHERE idEmpleado = NEW.idEmpleado
    AND FIni = NEW.FIni
  ) THEN
    RAISE EXCEPTION 'Un empleado solo puede tener una fecha de comienzo única.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
-- Disparador que lo implementa
CREATE TRIGGER enforce_employee_start_date
BEFORE INSERT ON ASIGNACION_TAREAS
FOR EACH ROW
EXECUTE FUNCTION check_employee_start_date();

-- Creación de un disparador que actualiza la bonificación en TAJINASTEPlus
-- después de una inserción en PEDIDO
CREATE OR REPLACE FUNCTION actualizar_bonificacion() RETURNS TRIGGER AS $$
BEGIN
    -- Actualizar la bonificación en TAJINASTEPlus basada en los pedidos
    UPDATE TAJINASTEPlus
    SET bonif = bonif + (
        SELECT SUM(Precio) * 0.03
        FROM PRODUCTO
        WHERE idProducto = NEW.idProducto
    )
    WHERE idTajinastePlus = NEW.dni_cliente;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
-- Agregar el disparador a la tabla PEDIDO
CREATE TRIGGER actualizar_bonificacion
AFTER INSERT ON PEDIDO
FOR EACH ROW
EXECUTE FUNCTION actualizar_bonificacion();


-- EJEMPLO DE INSERTS --

-- Insertar filas en la tabla CLIENTE
INSERT INTO CLIENTE (dni_cliente, Nombre, Apellidos, Tlf, Direccion)
VALUES
    ('11111111', 'Juan', 'Pérez', '612345678', 'Calle Sabina, 1'),
    ('22222222', 'María', 'Gómez', '623456789', 'Avenida Laurisilva, 22'),
    ('33333333', 'Luis', 'Martínez', '634567890', 'Calle Cedro, 3'),
    ('44444444', 'Ana', 'Sánchez', '645678901', 'Avenida Drago, 44'),
    ('55555555', 'Pedro', 'Rodríguez', '656789012', 'Calle Aceviño, 55');

-- Insertar filas en la tabla TAJINASTEPlus
INSERT INTO TAJINASTEPlus (idTajinastePlus, bonif)
VALUES
    ('11111111', 50),
    ('22222222', 30),
    ('33333333', 40),
    ('44444444', 20),
    ('55555555', 10);

-- Insertar filas en la tabla EMPLEADO
INSERT INTO EMPLEADO (idEMPLEADO, Nombre, Apellidos, Tlf, Direccion, DNI, productividad)
VALUES
    (1, 'Carlos', 'González', '123-456-789', 'Calle Principal 123', '12345678', 80.0),
    (2, 'Laura', 'Sánchez', '987-654-321', 'Avenida Central 456', '87654321', 85.0),
    (3, 'Miguel', 'López', '555-555-555', 'Calle Norte 789', '55555555', 90.0),
    (4, 'Sara', 'Martínez', '999-999-999', 'Avenida Sur 001', '99999999', 75.0),
    (5, 'Eduardo', 'Rodríguez', '111-111-111', 'Calle Este 987', '11111111', 70.0);

-- Insertar filas en la tabla VIVERO
INSERT INTO VIVERO (idVivero, nombreVivero)
VALUES
    (1, 'Vivero 1'),
    (2, 'Vivero 2'),
    (3, 'Vivero 3'),
    (4, 'Vivero 4'),
    (5, 'Vivero 5');

-- Insertar filas en la tabla ZONA
INSERT INTO ZONA (idZona, nombreZona, idVivero, latitud, longitud, productividad)
VALUES
    (1, 'Zona A', 1, 40.123456, -3.987654, 95.0),
    (2, 'Zona B', 1, 40.567890, -3.876543, 85.0),
    (3, 'Zona C', 2, 40.111111, -3.555555, 75.0),
    (4, 'Zona D', 3, 40.222222, -3.444444, 80.0),
    (5, 'Zona E', 4, 40.333333, -3.333333, 70.0);

-- Insertar filas en la tabla TAREA
INSERT INTO TAREA (idTarea, idZona, NombreTarea, Descripcion)
VALUES
    (1, 1, 'Tarea 1', 'Cultivo de Plantas'),
    (2, 1, 'Tarea 2', 'Mantenimiento'),
    (3, 2, 'Tarea 3', NULL),
    (4, 3, 'Tarea 4', 'Investigación y desarrollo'),
    (5, 4, 'Tarea 5', 'Diseño de jardines y paisajismo');

-- Insertar filas en la tabla PRODUCTO
INSERT INTO PRODUCTO (idProducto, NombreProducto, Descripcion, Precio)
VALUES
    (1, 'Cactus', NULL, 10.00),
    (2, 'Gravilla', 'Gravilla premium', 15.00),
    (3, 'Manguera', 'Manguera 25 metros', 20.00),
    (4, 'Abono orgánico', 'Producto ecologico', 25.00),
    (5, 'Maceta cerámica', NULL, 30.00);

-- Insertar filas en la tabla PEDIDO
INSERT INTO PEDIDO (idEmpleado, idProducto, fechaCompra, dni_cliente)
VALUES
    (1, 1, '2023-10-01', '11111111'),
    (2, 2, '2023-10-02', '22222222'),
    (3, 3, '2023-10-03', '33333333'),
    (4, 4, '2023-10-04', '44444444'),
    (5, 5, '2023-10-05', '55555555');

-- Insertar filas en la tabla ASIGNACION_TAREAS
INSERT INTO ASIGNACION_TAREAS (idEmpleado, idTarea, FIni, FFin)
VALUES
    (1, 1, '2023-10-01', '2023-10-02'),
    (2, 2, '2023-10-02', '2023-10-03'),
    (3, 3, '2023-10-03', '2023-10-04'),
    (4, 4, '2023-10-04', '2023-10-05'),
    (5, 5, '2023-10-05', '2023-10-06');