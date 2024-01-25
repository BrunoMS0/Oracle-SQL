-- Procedimiento para realizar una lista de las tiendas de Kuna:

CREATE OR REPLACE PROCEDURE Listar_Tiendas
IS
  v_sigla VARCHAR2(5);
  v_nombre VARCHAR2(50);
  v_direccion VARCHAR2(100);
  v_distrito VARCHAR2(15);
  v_departamento VARCHAR2(15);
  v_horaApertura TIMESTAMP;
  v_horaCierre TIMESTAMP;
  v_numTrabajadores NUMBER;
  v_aforo NUMBER;
  v_codJefe NUMBER;
  v_codAlmacenero NUMBER;
  
  CURSOR c_Tienda IS
    SELECT * FROM TIENDA;
BEGIN
  OPEN c_Tienda;

  LOOP
    FETCH c_Tienda INTO v_sigla, v_nombre, v_direccion, v_distrito, v_departamento, v_horaApertura,
            v_horaCierre, v_numTrabajadores, v_aforo, v_codJefe, v_codAlmacenero;
    EXIT WHEN c_Tienda%NOTFOUND;
    
    DBMS_OUTPUT.PUT_LINE('TIENDA:  ' || v_nombre);
    DBMS_OUTPUT.PUT_LINE('----------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE( RPAD('Sigla:',30) || RPAD(v_sigla, 40));
    DBMS_OUTPUT.PUT_LINE( RPAD('Dirección:',30) || RPAD(v_direccion, 40));
    DBMS_OUTPUT.PUT_LINE(RPAD('Distrito:',30) || RPAD(v_distrito, 40));
    DBMS_OUTPUT.PUT_LINE(RPAD('Departamento:',30) || RPAD(v_departamento, 40));
    DBMS_OUTPUT.PUT_LINE(RPAD('Hora de Apertura:',30) || RPAD(TO_CHAR(v_horaApertura, 'HH24:MI:SS'), 40));
    DBMS_OUTPUT.PUT_LINE(RPAD('Hora de cierre:',30) || RPAD(TO_CHAR(v_horaCierre, 'HH24:MI:SS'), 40));
    DBMS_OUTPUT.PUT_LINE(RPAD('Numero de trabajadores:',30) || RPAD(v_numTrabajadores, 40));
    DBMS_OUTPUT.PUT_LINE(RPAD('Aforo:',30) || RPAD(v_aforo, 40));
    DBMS_OUTPUT.PUT_LINE(RPAD('Codigo del Jefe de tienda:',30) || RPAD(v_codJefe, 40));
    DBMS_OUTPUT.PUT_LINE(RPAD('Codigo del Almacenero:',30) || RPAD(v_codAlmacenero, 40));

    DBMS_OUTPUT.PUT_LINE('----------------------------------------------------');
  END LOOP;

  CLOSE c_Tienda;
END;

exec Listar_Tiendas;
/

-- Procedimiento para insertar un nuevo cliente:

CREATE SEQUENCE secuencia_cliente
    INCREMENT BY 1
    START WITH 51
    NOMAXVALUE
    NOMINVALUE;

CREATE OR REPLACE PROCEDURE Insertar_Cliente_Nuevo(
    p_dni_cliente IN VARCHAR2,
    p_apaterno IN VARCHAR2,
    p_amaterno IN VARCHAR2,
    p_nombre IN VARCHAR2,
    p_telefono IN VARCHAR2,
    p_correo IN VARCHAR2
)
IS
    v_codigo_cliente NUMBER;
BEGIN
    -- Iniciar la transacción
    BEGIN
        SELECT secuencia_cliente.NEXTVAL INTO v_codigo_cliente FROM DUAL;

        -- Insertar el nuevo cliente
        INSERT INTO cliente
        VALUES (v_codigo_cliente, p_dni_cliente, p_apaterno, p_amaterno, p_nombre, p_telefono, p_correo);

        -- Comprobar si el cliente fue insertado correctamente
        IF SQL%ROWCOUNT > 0 THEN
            -- Commit si el cliente se insertó correctamente
            COMMIT;
            DBMS_OUTPUT.PUT_LINE('Se insertó al nuevo cliente correctamente');
        ELSE
            -- Rollback si no se pudo insertar al cliente
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('No se pudo insertar al nuevo cliente');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM); -- No se pudo insertar debido a un error
    END;
END;

delete from cliente where dni='07773422';
delete from cliente where dni='08883424';

exec Insertar_Cliente_Nuevo('07773422', 'Mendoza', 'Aldana', 'Joel', '+51 997541111','joelaldana@gmail.com');
exec Insertar_Cliente_Nuevo('08883424', 'Medina', 'Alberto', 'Juan', '+51 997542412','juanalberto@gmail.com');
/


--Procedimiento para agregar el subtotal a la tabla producto_comprobante:

CREATE OR REPLACE PROCEDURE agrega_subtotal
IS
BEGIN
    UPDATE producto_comprobante pc
    SET pc.subtotal = (
        SELECT pc.cantidadxproducto * pv.precio
        FROM productoversion pv
        WHERE pv.id_version = pc.id_version AND pc.id_producto = pv.id_producto
    );
END;

update producto_comprobante set subtotal=0;

exec agrega_subtotal;
/

--Procedimiento para calcular el total en la tabla comprobante_pago:

CREATE OR REPLACE PROCEDURE agrega_total
IS
BEGIN
    UPDATE comprobante_pago cp
    SET cp.total = (
        SELECT sum(pc.subtotal)
        FROM producto_comprobante pc
        WHERE pc.id_comprobante = cp.id_comprobante
    );
END;

update comprobante_pago set total=0;

exec agrega_total;
/


--Procedimiento para actualizar el sueldo de un vendedor de acuerdo a la ventas generadas:

CREATE OR REPLACE PROCEDURE ACTUALIZA_COMISION_SUELDO(
    fecha_ini IN DATE,
    fecha_fin IN DATE
)
IS
    CURSOR c_vendedor IS
    SELECT codigo_vendedor
    FROM vendedor;

    v_id_vendedor NUMBER;
    v_total_venta NUMBER(10, 2);
    v_venderNotFound EXCEPTION;
BEGIN
    OPEN c_vendedor;
        LOOP
            FETCH c_vendedor INTO v_id_vendedor;
            
            EXIT WHEN c_vendedor%NOTFOUND;

            BEGIN
                SELECT SUM(TOTAL) INTO v_total_venta
                FROM comprobante_pago
                WHERE codigo_vendedor = v_id_vendedor
                AND TRUNC(fecha_emision) >= fecha_ini 
                AND TRUNC(fecha_emision) <= fecha_fin;

                IF v_total_venta IS NOT NULL THEN
                    UPDATE vendedor
                    SET sueldo = sueldo + (v_total_venta * comisión)
                    WHERE codigo_vendedor = v_id_vendedor;
                    DBMS_OUTPUT.PUT_LINE('Se actualizó el sueldo del vendedor ' || v_id_vendedor || ' con éxito.');
                ELSE
                    RAISE v_venderNotFound;
                END IF;

            EXCEPTION
                 WHEN v_venderNotFound THEN
                    DBMS_OUTPUT.PUT_LINE('No se encontraron registros de comprobantes de pago para el vendedor ' || v_id_vendedor);
            END;
        END LOOP;

        -- Confirmar la transacción
        DBMS_OUTPUT.PUT_LINE('Se terminó el proceso de actualización del sueldo de los vendedores');

    EXCEPTION
        WHEN OTHERS THEN
            -- Deshacer la transacción en caso de error
            DBMS_OUTPUT.PUT_LINE('Ocurrió un error. Se deshicieron los cambios realizados.');
    CLOSE c_vendedor;
END;

exec ACTUALIZA_COMISION_SUELDO(to_date('01/06/20','dd/mm/yy'),to_date('28/06/20', 'dd/mm/yy'));
/

--Procedimiento para mostrar datos de un producto y su stock:

CREATE OR REPLACE PROCEDURE ListarProductos(
    p_descripcion VARCHAR2
)
IS
    CURSOR c_producto IS
        SELECT p.id_producto, p.descripcion, tp.stock, tp.tienda_sigla,tp.id_version
        FROM producto p, tienda_productoversion tp
        WHERE p.descripcion = p_descripcion AND p.id_producto = tp.id_producto;

    v_idProducto NUMBER;
    v_idProducto_anterior Number :=null;
    v_descripcion VARCHAR2(100);
    v_stock NUMBER;
    v_stockTotal NUMBER :=0;
    v_id_version number;
    v_tienda_sigla varchar2(5);
    v_tienda_anterior varchar(5) :=null;
BEGIN
    OPEN c_producto;


    LOOP
        FETCH c_producto INTO v_idProducto, v_descripcion, v_stock, v_tienda_sigla,v_id_version;
        EXIT WHEN c_producto%NOTFOUND;
        
        if v_tienda_anterior is null then
            DBMS_OUTPUT.PUT_LINE('Tienda: '|| v_tienda_sigla); 
            DBMS_OUTPUT.PUT_LINE('-----------------------------------------');
            v_tienda_anterior:=v_tienda_sigla;
        end if;
        
        if v_tienda_sigla != v_tienda_anterior then
            if v_tienda_anterior is not null then
                DBMS_OUTPUT.PUT_LINE('Stock Total: ' || v_stockTotal);
                DBMS_OUTPUT.PUT_LINE(' ');
                v_stockTotal :=0;
            end if;
           DBMS_OUTPUT.PUT_LINE('Tienda: '|| v_tienda_sigla); 
           v_tienda_anterior:=v_tienda_sigla;
        end if;
        
        if v_idProducto_anterior is null then 
            DBMS_OUTPUT.PUT_LINE('ID Producto: ' || v_idProducto ||
        ', Descripcion: ' || v_descripcion); 
        DBMS_OUTPUT.PUT_LINE('-----------------------------------------');
            v_idProducto_anterior:=v_idproducto;
        end if;
        
        if v_idProducto_anterior != v_idProducto then
           DBMS_OUTPUT.PUT_LINE('ID Producto: ' || v_idProducto ||
        ', Descripcion: ' || v_descripcion); 
            v_idProducto_anterior:=v_idproducto;
        end if;
        
        DBMS_OUTPUT.PUT_LINE( 'ID_VERSION: '|| v_id_version ||', Stock: ' || v_stock);
        
        v_stocktotal:=v_stocktotal+v_stock;
    END LOOP;

    CLOSE c_producto;
    
    if v_tienda_anterior is not null then  
        DBMS_OUTPUT.PUT_LINE('-----------------------------------------');
        DBMS_OUTPUT.PUT_LINE('Sotck Total: ' || v_stocktotal);
    end if;
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('No se encontraron productos para la categoría especificada.');
	WHEN OTHERS THEN
            ROLLBACK TO inicio_transaccion;
            DBMS_OUTPUT.PUT_LINE('Error al listar los productos: ' || SQLERRM);
END;

exec listarproductos('ABRIGO ANASTASIA');
/

--Trigger para disminuir el stock de un producto determinado dependiendo de las ventas que se realicen:

CREATE OR REPLACE TRIGGER actualiza_stock_producto_venta
AFTER INSERT ON producto_comprobante
FOR EACH ROW
DECLARE 
    v_id_tienda VARCHAR(5);

BEGIN
    SELECT tienda_sigla into v_id_tienda
    FROM comprobante_pago
    WHERE id_comprobante = :NEW.id_comprobante;
    
    UPDATE tienda_productoversion
    SET  stock = stock - :NEW.cantidadxproducto
    WHERE  id_producto = :NEW.id_producto AND id_version = :NEW.id_version 
            AND tienda_sigla = v_id_tienda;
END; 
	
/

insert into producto_comprobante values (35,9,10,5,500);

--Procedimiento para actualizar el stock en base a los ingresos del almacen

CREATE OR REPLACE PROCEDURE actualizar_stock (
  p_cantidad_ingresada IN ingreso.cantidad_total%TYPE,
  p_id_ingreso IN ingreso.codigo_guia%TYPE
)
IS
  v_stock_actual ingreso.cantidad_total%TYPE;
BEGIN
  -- Obtener el stock actual del ingreso
  SELECT cantidad_total INTO v_stock_actual
  FROM ingreso
  WHERE codigo_guia = p_id_ingreso;

  v_stock_actual := v_stock_actual + p_cantidad_ingresada;

  UPDATE ingreso
  SET cantidad_total = v_stock_actual
  WHERE codigo_guia = p_id_ingreso;
  
  COMMIT;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20001, 'No se encontró ningún ingreso con el ID especificado');
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20002, 'Error al actualizar el stock del almacén: ' || SQLERRM);
END;

exec actualizar_stock(10, 1);
exec actualizar_Stock_Almacen(10,2);
exec actualizar_Stock_Almacen(10,5);

--Procedimiento para leer ventas

CREATE OR REPLACE PROCEDURE 
leer_ventas_por_fecha (
  v_fecha_inicio IN DATE,
  v_fecha_fin IN DATE
)
IS
BEGIN
  FOR detalle_venta_online IN (
    SELECT id_DetalleOnline, ID_Comprobante, Fecha_Registrada, Fecha_Entrega, Estado
    FROM detalle_venta_online
    WHERE fecha_Registrada between v_fecha_inicio and v_fecha_fin
  )
  LOOP
    -- Realizar las operaciones necesarias con los datos de la venta
    -- Puedes imprimirlos en pantalla, almacenarlos en variables adicionales, etc.
    DBMS_OUTPUT.PUT_LINE('ID Detalle online: ' || detalle_venta_online.id_DetalleOnline);
    DBMS_OUTPUT.PUT_LINE('Id comprobante: ' || detalle_venta_online.ID_Comprobante);
    DBMS_OUTPUT.PUT_LINE('Fecha registrada: ' || detalle_venta_online.Fecha_Registrada);
    DbMS_OUTPUT.PUT_LINE('Fecha de entrega: ' || detalle_venta_online.Fecha_Entrega);
    DBMS_OUTPUT.PUT_LINE('Estado: ' || detalle_venta_online.Estado);
    DBMS_OUTPUT.PUT_LINE('------------------------------');
  END LOOP;
END;

exec leer_ventas_por_fecha('01/02/2022','12/03/2022');

/

--Procedimiento para eliminar vendedor:

CREATE OR REPLACE PROCEDURE eliminarVendedor(p_codigoVendedor number)
IS
BEGIN
    BEGIN
        SAVEPOINT inicio_transaccion;
        UPDATE comprobante_pago
        SET codigo_vendedor=NULL
        WHERE codigo_vendedor=p_codigoVendedor;
        
        DELETE FROM vendedor WHERE codigo_vendedor = p_codigoVendedor;
        COMMIT;
        
        DBMS_OUTPUT.PUT_LINE('El vendedor con codigo de vendedor ' || 
        p_codigoVendedor || ' ha sido eliminado');
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('No se encontró un vendedor con el codigo 
            vendedor especificado');
        WHEN OTHERS THEN
            ROLLBACK TO inicio_transaccion;
            DBMS_OUTPUT.PUT_LINE('Error al eliminar el empleado: ' || SQLERRM);
    END;
END;

exec eliminarVendedor (221007);
/
