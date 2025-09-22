-- Tabela de Hotéis
CREATE TABLE Hotels (
    hotel_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    address VARCHAR(200),
    rating INT CHECK (rating BETWEEN 1 AND 5) -- classificação 1 a 5 estrelas
);

-- Tipos de Quartos
CREATE TABLE RoomTypes (
    roomtype_id SERIAL PRIMARY KEY,
    type_name VARCHAR(50) NOT NULL,  -- Ex: Standard, Deluxe, Suite
    description TEXT
);

-- Quartos
CREATE TABLE Rooms (
    room_id SERIAL PRIMARY KEY,
    hotel_id INT REFERENCES Hotels(hotel_id) ON DELETE CASCADE,
    roomtype_id INT REFERENCES RoomTypes(roomtype_id) ON DELETE CASCADE,
    room_number VARCHAR(10) NOT NULL,
    UNIQUE (hotel_id, room_number) -- evita duplicação de número no mesmo hotel
);

-- Clientes
CREATE TABLE Customers (
    customer_id SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20)
);

-- Reservas
CREATE TABLE Reservations (
    reservation_id SERIAL PRIMARY KEY,
    room_id INT REFERENCES Rooms(room_id) ON DELETE CASCADE,
    customer_id INT REFERENCES Customers(customer_id) ON DELETE CASCADE,
    checkin_date DATE NOT NULL,
    checkout_date DATE NOT NULL,
    status VARCHAR(20) DEFAULT 'Active', -- Active, Cancelled
    CONSTRAINT valid_dates CHECK (checkin_date < checkout_date)
);
