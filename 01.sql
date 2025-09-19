-- 1) vw_detalhes_pedidos
-- Exibir todos os pedidos junto com o nome do cliente, status, total do pedido e quantidade total de itens.

create or replace view vw_detalhes_pedidos 
as select 
	o.order_id,
	c.first_name,
	c.last_name,
	o.order_status,
	o.total_amount,
	sum(oi.quantity) as total_items
From orders o 
join customers c on c.customer_id = o.customer_id
join order_items oi on oi.order_id = o.order_id 
group by
	o.order_id,
	c.first_name,
	c.last_name,
	o.order_status,
	o.total_amount;

-- 2) vw_produtos_ativos_categoria
-- Listar produtos ativos com nome da categoria, preço e margem bruta (diferença entre preço e custo).

create or replace view vw_produtos_ativos_categorias 
as select 
	p.active,
	p.category_id,
	p.price,
	p.cost
from products p 
join categories c on p.category_id = c.category_id
group by 
	p.active,
	p.category_id,
	p.price,
	p.cost;

-- 3) vw_clientes_sem_pedidos
-- Mostrar clientes que não possuem nenhum pedido registrado no sistema.

create or replace view vw_clientes_sem_pedidos
as select  
	c.first_name,
	c.email
from customers c join orders o
on c.customer_id = o.customer_id
where order_id = NULL;

-- 4) vw_faturamento_por_categoria
-- Somar o valor total (line_total) dos itens de pedido por categoria de produto, 
-- apenas para pedidos com status Shipped ou Completed.

CREATE OR REPLACE VIEW vw_faturamento_por_categoria AS
SELECT cat.name AS categoria,
       SUM(oi.line_total) AS total_faturado
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
JOIN categories cat ON cat.category_id = p.category_id
JOIN orders o ON o.order_id = oi.order_id
WHERE o.order_status IN ('Shipped', 'Completed')
GROUP BY cat.name; 
	

--5) vw_pedidos_pagamentos_pendentes
-- Listar pedidos cujo valor total ainda não foi quitado (diferença entre soma dos
-- pagamentos e o total do pedido).

CREATE OR REPLACE VIEW vw_pedidos_pagamentos_pendentes AS
SELECT 
    o.order_id,
    o.total_amount,
    SUM(p.amount) AS total_pago,
    o.total_amount - SUM(p.amount) AS valor_pendente
FROM orders o
LEFT JOIN payments p ON o.order_id = p.order_id
GROUP BY o.order_id, o.total_amount
HAVING SUM(p.amount) < o.total_amount;	

SELECT * FROM vw_pedidos_pagamentos_pendentes;

--6) sp_update_order_status(order_id BIGINT, new_status TEXT)
--Atualiza orders.order_status validando que o novo status esteja em (Pending,
--Shipped, Completed, Cancelled). Em caso inválido, lança erro. Sem retorno.

CREATE OR REPLACE PROCEDURE sp_update_order_status(p_order_id BIGINT, p_new_status TEXT)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_new_status NOT IN ('Pending','Shipped','Completed','Cancelled') THEN
        RAISE EXCEPTION 'Status inválido';
    END IF;
    UPDATE orders SET order_status = p_new_status WHERE order_id = p_order_id;
END;
$$;


--7) sp_set_primary_address(customer_id BIGINT, address_id BIGINT)
--Em transação, remove o is_primary de todos os endereços do cliente e define
--is_primary = TRUE apenas para o address_id informado. Sem retorno.


CREATE OR REPLACE PROCEDURE sp_set_primary_address(p_customer_id BIGINT, p_address_id BIGINT)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE addresses SET is_primary = FALSE WHERE customer_id = p_customer_id;
    UPDATE addresses SET is_primary = TRUE WHERE address_id = p_address_id AND customer_id = p_customer_id;
END;
$$;

--8) sp_apply_item_discount(order_item_id BIGINT, discount_amount
--NUMERIC(12,2))
--Atualiza order_items.discount_amount e recalcula line_total = quantity*unit_price -
--discount_amount. Em seguida, recalcula orders.total_amount somando os line_total
--de todos os itens do pedido. Sem retorno.

CREATE OR REPLACE PROCEDURE sp_apply_item_discount(p_order_item_id BIGINT, p_discount NUMERIC)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE order_items
    SET discount_amount = p_discount,
        line_total = (quantity * unit_price) - p_discount
    WHERE order_item_id = p_order_item_id;

    UPDATE orders
    SET total_amount = (SELECT SUM(line_total) FROM order_items WHERE order_id = (SELECT order_id FROM order_items WHERE order_item_id = p_order_item_id))
    WHERE order_id = (SELECT order_id FROM order_items WHERE order_item_id = p_order_item_id);
END;
$$;


--9) sp_record_payment(order_id BIGINT, method TEXT, amount NUMERIC(12,2),
--currency CHAR(3), transaction_ref TEXT)
--Insere um registro em payments. Após inserir, verifica o total pago do pedido; se
--atingir ou exceder orders.total_amount, marca o pagamento mais recente como
--Completed e atualiza orders.order_status para Completed. Sem retorno.

CREATE OR REPLACE PROCEDURE sp_record_payment(p_order_id BIGINT, p_method TEXT, p_amount NUMERIC, p_currency CHAR(3), p_transaction_ref TEXT)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO payments(order_id, payment_method, amount, currency, paid_at, status, transaction_ref)
    VALUES (p_order_id, p_method, p_amount, p_currency, NOW(), 'Pending', p_transaction_ref);

    UPDATE payments
    SET status = 'Completed'
    WHERE payment_id = (SELECT MAX(payment_id) FROM payments WHERE order_id = p_order_id)
      AND (SELECT SUM(amount) FROM payments WHERE order_id = p_order_id) >= 
          (SELECT total_amount FROM orders WHERE order_id = p_order_id);

    UPDATE orders
    SET order_status = 'Completed'
    WHERE order_id = p_order_id
      AND (SELECT SUM(amount) FROM payments WHERE order_id = p_order_id) >= 
          (SELECT total_amount FROM orders WHERE order_id = p_order_id);
END;
$$;


--10) sp_reprice_order_by_min_margin(order_id BIGINT, min_margin_percent
--NUMERIC)
--Para cada item do pedido, se a margem bruta (unit_price - cost) / unit_price estiver
--abaixo de min_margin_percent, ajusta unit_price para cumprir a margem mínima
--(não altera cost). Recalcula line_total e o orders.total_amount. Sem retorno.

CREATE OR REPLACE PROCEDURE sp_reprice_order_by_min_margin(p_order_id BIGINT, p_min_margin NUMERIC)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE order_items oi
    SET unit_price = p.cost / (1 - p_min_margin),
        line_total = (oi.quantity * (p.cost / (1 - p_min_margin))) - oi.discount_amount
    FROM products p
    WHERE oi.product_id = p.product_id
      AND oi.order_id = p_order_id
      AND (oi.unit_price - p.cost)/oi.unit_price < p_min_margin;

    UPDATE orders
    SET total_amount = (SELECT SUM(line_total) FROM order_items WHERE order_id = p_order_id)
    WHERE order_id = p_order_id;
END;
$$;
	