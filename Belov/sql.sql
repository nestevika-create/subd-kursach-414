CREATE TABLE departments 
(id_dep serial4 PRIMARY KEY,
name varchar UNIQUE NOT NULL);
 
Create table place
(id_p serial4 primary key,
id_dep int4 not null,
name varchar not null,
position varchar not null,
FOREIGN KEY (id_dep) REFERENCES departments (id_dep));

Create table objects
(id_ob serial4 primary key,
object_name varchar not null,
object_cod UNIQUE varchar not null,
creation_year int4,
IMAGE varchar,
description varchar);

Create table time
(id_time serial4 primary key,
day DATE NOT NULL);

Create table Inventory_Log
(id serial4 primary key,
id_ob int4 not null,
id_time int4 not null,
id_p int4 not null,
count int4 not null CHECK (count >= 0),
FOREIGN KEY (id_ob) REFERENCES objects (id_ob),
FOREIGN KEY (id_time) REFERENCES time (id_time),
FOREIGN KEY (id_p) REFERENCES place (id_p));

CREATE TABLE users
(id_u serial4 primary key,
login varchar(50) NOT NULL,
role varchar(50) not null,
password varchar (50) not null,
id_dep int4,
FOREIGN KEY (id_dep) REFERENCES depertaments (id_dep));



CREATE OR REPLACE VIEW v_full_Inventory_Log AS
SELECT 
    h.id AS Inventory_Log_id,
    o.object_name,
    o.object_cod,
    p.name AS place_name,
    p.position AS place_position,
    h.count,
    o.description,
    t.day AS date_record
FROM Inventory_Log h
JOIN objects o ON h.id_ob = o.id_ob
JOIN place p ON h.id_p = p.id_p
JOIN time t ON h.id_time = t.id_time;

CREATE OR REPLACE VIEW v_rooms_responsible AS
SELECT 
    d.name AS department_name,      
    p.name AS room_name,            
    p.position AS room_position,    
    u.login AS responsible_person,  
    u.role AS person_role           
FROM place p
JOIN departments d ON p.id_dep = d.id_dep
LEFT JOIN users u ON d.id_dep = u.id_dep -- LEFT JOIN: покажет комнату, даже если нет юзера
ORDER BY d.name, p.name;


-- Добавление времени (даты)
CREATE OR REPLACE PROCEDURE pr_add_time(
    _day DATE
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Вставляем только если такой даты нет
    INSERT INTO time (day)
    VALUES (_day)
    ON CONFLICT DO NOTHING; -- Требует UNIQUE constraint на поле day, либо уберите эту строку
END;
$$;


CREATE OR REPLACE PROCEDURE pr_add_place(
    _id_dep int4,
    _name varchar, 
    _position varchar
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO place (id_dep, name, position)
    VALUES (_id_dep, _name, _position);
END;
$$;


CREATE OR REPLACE PROCEDURE pr_add_object(
    _object_name varchar,
    _object_cod varchar,
    _creation_year int4,
    _image varchar
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO objects (object_name, object_cod, creation_year, IMAGE)
    VALUES (_object_name, _object_cod, _creation_year, _image);
END;
$$;


CREATE OR REPLACE PROCEDURE pr_add_user(
    _login varchar, 
    _password varchar,
    _role varchar,
    _id_dep int4
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO users (login, password, role, id_dep)
    VALUES (_login, _password, _role, _id_dep);
    
    EXCEPTION WHEN unique_violation THEN
        RAISE NOTICE 'Пользователь с логином % уже существует.', _login;
END;
$$;


CREATE OR REPLACE PROCEDURE pr_add_Inventory_Log(
    _id_ob int4,
    _id_time int4, 
    _id_p int4,
    _count int4
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM objects WHERE id_ob = _id_ob) THEN
        RAISE EXCEPTION 'Объект с ID % не найден', _id_ob;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM time WHERE id_time = _id_time) THEN
        RAISE EXCEPTION 'Время с ID % не найдено', _id_time;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM place WHERE id_p = _id_p) THEN
        RAISE EXCEPTION 'Место с ID % не найдено', _id_p;
    END IF;

    INSERT INTO Inventory_Log (id_ob, id_time, id_p, count)
    VALUES (_id_ob, _id_time, _id_p, _count);
END;
$$;



CALL pr_add_place('Главный склад', 'Полка 5');

CALL pr_add_object('Монитор', 'MON-24', 2024, NULL);

CALL pr_add_user('admin', 'admin123');

CALL pr_add_Inventory_Log(1, 1, 1, 1, 50);




CREATE OR REPLACE FUNCTION fn_show_places()
RETURNS TABLE (
    id int4,
    dept_id int4,
    place_name varchar,
    position_info varchar
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT id_p, id_dep, name, position
    FROM place
    ORDER BY id_p;
END;
$$;


CREATE OR REPLACE FUNCTION fn_show_objects()
RETURNS TABLE (
    id int4,
    name varchar,
    code varchar,
    created_year int4,
    img_path varchar
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT id_ob, object_name, object_cod, creation_year, IMAGE
    FROM objects
    ORDER BY object_name;
END;
$$;


CREATE OR REPLACE FUNCTION fn_show_users()
RETURNS TABLE (
    id int4,
    user_login varchar,
    user_role varchar,
    dept_id int4
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT id_u, login, role, id_dep
    FROM users
    ORDER BY id_u;
END;
$$;


CREATE OR REPLACE FUNCTION fn_get_my_inventory(_user_id int4)
RETURNS TABLE (
    Inventory_Log_id int4,
    obj_name varchar,
    obj_code varchar,
    place_name varchar,
    dept_name varchar,
    count int4,
    date_info date
)
LANGUAGE plpgsql
AS $$
DECLARE
    _user_role varchar;
    _user_dep int4;
BEGIN
    SELECT role, id_dep INTO _user_role, _user_dep
    FROM users
    WHERE id_u = _user_id;

    RETURN QUERY
    SELECT 
        h.id,
        o.object_name,
        o.object_cod,
        p.name AS place_name,
        d.name AS dept_name,
        h.count,
        t.day -- Прямой вывод даты
    FROM Inventory_Log h
    JOIN objects o ON h.id_ob = o.id_ob
    JOIN place p ON h.id_p = p.id_p
    JOIN departments d ON p.id_dep = d.id_dep
    JOIN time t ON h.id_time = t.id_time
    WHERE 
        (_user_role = 'admin') 
        OR 
        (d.id_dep = _user_dep); 
END;
$$;



CREATE OR REPLACE PROCEDURE pr_delete_Inventory_Log_by_details(
    _obj_name varchar,
    _month varchar,
    _year int4,
    _place_name varchar,
    _count int4
)
LANGUAGE plpgsql
AS $$
DECLARE
    deleted_rows int;
BEGIN

    DELETE FROM Inventory_Log h
    USING objects o, time t, place p
    WHERE h.id_ob = o.id_ob
      AND h.id_time = t.id_time
      AND h.id_p = p.id_p

      AND o.object_name = _obj_name
      AND t.mounth = _month
      AND t.year = _year
      AND p.name = _place_name
      AND h.count = _count;

    GET DIAGNOSTICS deleted_rows = ROW_COUNT;

    IF deleted_rows = 0 THEN
        RAISE NOTICE 'Запись не найдена. Проверьте точность введенных данных (регистр букв важен).';
    ELSE
        RAISE NOTICE 'Удалено записей: %', deleted_rows;
    END IF;
END;
$$;


CREATE OR REPLACE PROCEDURE pr_delete_Inventory_Log_by_details(
    _obj_name varchar,
    _day DATE,         -- Вместо месяца и года теперь одна дата
    _place_name varchar,
    _count int4
)
LANGUAGE plpgsql
AS $$
DECLARE
    deleted_rows int;
BEGIN
    DELETE FROM Inventory_Log h
    USING objects o, time t, place p
    WHERE h.id_ob = o.id_ob
      AND h.id_time = t.id_time
      AND h.id_p = p.id_p
      -- Условия фильтрации
      AND o.object_name = _obj_name
      AND t.day = _day -- Сравнение даты
      AND p.name = _place_name
      AND h.count = _count;

    GET DIAGNOSTICS deleted_rows = ROW_COUNT;

    IF deleted_rows = 0 THEN
        RAISE NOTICE 'Запись не найдена. Проверьте данные.';
    ELSE
        RAISE NOTICE 'Удалено записей: %', deleted_rows;
    END IF;
END;
$$;


CREATE OR REPLACE PROCEDURE pr_edit_object(
    _current_code varchar,
    _new_name varchar,
    _new_code varchar,
    _new_year int4,
    _new_image varchar,
    _new_description varchar
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE objects
    SET object_name = _new_name,
        object_cod = _new_code,
        creation_year = _new_year,
        IMAGE = _new_image,
        description = _new_description
    WHERE object_cod = _current_code;

    IF NOT FOUND THEN
        RAISE NOTICE 'Объект с кодом "%" не найден.', _current_code;
    END IF;
END;
$$;

-- Редактирование места (Без изменений)
CREATE OR REPLACE PROCEDURE pr_edit_place_by_name(
    _current_name varchar,  
    _new_name varchar,      
    _new_position varchar   
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE place
    SET name = _new_name,
        position = _new_position
    WHERE name = _current_name;

    IF NOT FOUND THEN
        RAISE NOTICE 'Место с названием "%" не найдено.', _current_name;
    END IF;
END;
$$;




CREATE OR REPLACE PROCEDURE pr_edit_object_by_code(
    _current_code varchar,  -- Код объекта, который ищем
    _new_name varchar,
    _new_code varchar,      -- Новый код (можно оставить прежним)
    _new_year int4,
    _new_image varchar,
    _new_description varchar
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE objects
    SET object_name = _new_name,
        object_cod = _new_code,
        creation_year = _new_year,
        IMAGE = _new_image,
        description = _new_description
    WHERE object_cod = _current_code;

    IF NOT FOUND THEN
        RAISE NOTICE 'Объект с кодом "%" не найден.', _current_code;
    END IF;
END;
$$;


CREATE OR REPLACE PROCEDURE pr_edit_place_by_name(
    _current_name varchar,  
    _new_name varchar,      
    _new_position varchar   
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE place
    SET name = _new_name,
        position = _new_position
    WHERE name = _current_name;

    IF NOT FOUND THEN
        RAISE NOTICE 'Место с названием "%" не найдено.', _current_name;
    END IF;
END;

$$;


    
INSERT INTO departments (name) VALUES 
('IT Отдел'),
('Бухгалтерия'),
('Администрация'),
('Склад материалов');

    
INSERT INTO time (day) VALUES 
('2024-01-15'), 
('2024-06-20'),
('2025-01-10'); 


INSERT INTO objects (object_name, object_cod, creation_year, IMAGE, description) VALUES 
('Ноутбук Dell Latitude', 'NB-00154', 2023, '/img/dell.jpg', 'Служебный ноутбук инженера'),
('Монитор Samsung 24"', 'MON-7782', 2022, NULL, 'Изогнутый экран'),
('Кресло офисное', 'CH-001', 2021, NULL, 'Черное, кожаное'),
('Принтер HP LaserJet', 'PRN-Kyocera', 2020, '/img/prn.png', 'Сетевой принтер'),
('Степлер канцелярский', 'OFF-05', 2024, NULL, 'Красный');

    
INSERT INTO place (id_dep, name, position) VALUES 
(1, 'Серверная №1', 'Стойка А'),  
(1, 'Кабинет Сисадминов', 'Стол 2'),
(2, 'Кабинет Главбуха', 'Сейф'), 
(4, 'Ангар А', 'Сектор 5 (Верх)');
  
INSERT INTO users (login, role, password, id_dep) VALUES 
('admin', 'admin', 'admin_pass', 1),        
('accountant_anna', 'user', 'money123', 2),  
('storekeeper_ivan', 'user', 'stock777', 4),
('manager_petr', 'user', 'boss2025', 3); 


INSERT INTO history (id_ob, id_time, id_p, count) VALUES 
(1, 1, 1, 5),
(1, 2, 2, 2),
(2, 3, 3, 1),
(3, 1, 4, 50),
(4, 3, 3, 1);

SELECT * FROM v_full_history;

SELECT * FROM fn_get_my_inventory(1); 

SELECT * FROM fn_get_my_inventory(2);

