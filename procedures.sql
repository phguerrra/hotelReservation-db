CREATE OR REPLACE FUNCTION CheckRoomAvailability(
    p_hotel_id INT,
    p_checkin DATE,
    p_checkout DATE
)
RETURNS TABLE(room_id INT, room_number VARCHAR, type_name VARCHAR) AS $$
BEGIN
    RETURN QUERY
    SELECT r.room_id, r.room_number, rt.type_name
    FROM Rooms r
    JOIN RoomTypes rt ON r.roomtype_id = rt.roomtype_id
    WHERE r.hotel_id = p_hotel_id
      AND r.room_id NOT IN (
          SELECT res.room_id
          FROM Reservations res
          WHERE res.status = 'Active'
            AND (p_checkin < res.checkout_date AND p_checkout > res.checkin_date)
      );
END;
$$ LANGUAGE plpgsql;

-- Criar uma reserva
CREATE OR REPLACE FUNCTION CreateReservation(
    p_room_id INT,
    p_customer_id INT,
    p_checkin DATE,
    p_checkout DATE
)
RETURNS INT AS $$
DECLARE
    v_reservation_id INT;
BEGIN
    -- Verifica se o quarto está disponível
    IF EXISTS (
        SELECT 1 FROM Reservations
        WHERE room_id = p_room_id
          AND status = 'Active'
          AND (p_checkin < checkout_date AND p_checkout > checkin_date)
    ) THEN
        RAISE EXCEPTION 'Quarto não disponível nesse período';
    END IF;

    -- Insere a reserva
    INSERT INTO Reservations(room_id, customer_id, checkin_date, checkout_date, status)
    VALUES (p_room_id, p_customer_id, p_checkin, p_checkout, 'Active')
    RETURNING reservation_id INTO v_reservation_id;

    RETURN v_reservation_id;
END;
$$ LANGUAGE plpgsql;


-- Cancelar reserva
CREATE OR REPLACE FUNCTION CancelReservation(p_reservation_id INT)
RETURNS VOID AS $$
BEGIN
    UPDATE Reservations
    SET status = 'Cancelled'
    WHERE reservation_id = p_reservation_id;

    IF NOT FOUND THEN
        RAISE NOTICE 'Reserva não encontrada';
    END IF;
END;
$$ LANGUAGE plpgsql;

