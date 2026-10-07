package fi.metropolia.webstore.service;

import fi.metropolia.webstore.dto.CategorySales;
import fi.metropolia.webstore.entity.OrderStatus;
import fi.metropolia.webstore.repository.OrderItemRepository;
import fi.metropolia.webstore.repository.OrderRepository;
import fi.metropolia.webstore.repository.ProductRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

// Massaoperaatiot. Transaktio on palvelutasolla: @Modifying-kyselyt ja CriteriaUpdate vaativat
// aktiivisen transaktion, ja virhe peruu koko joukkomuutoksen.
@Service
public class MassOperationService {

    private static final Logger log = LoggerFactory.getLogger(MassOperationService.class);

    private final OrderRepository orders;
    private final OrderItemRepository orderItems;
    private final ProductRepository products;

    public MassOperationService(OrderRepository orders, OrderItemRepository orderItems, ProductRepository products) {
        this.orders = orders;
        this.orderItems = orderItems;
        this.products = products;
    }

    // JPQL UPDATE: vanhentuneet käsittelemättömät tilaukset perutaan.
    @Transactional
    public int cancelStaleOrders(LocalDateTime cutoff) {
        long before = orders.countByStatusBefore(OrderStatus.UUSI, cutoff);
        int updated = orders.bulkChangeStatus(OrderStatus.UUSI, OrderStatus.PERUTTU, cutoff);
        long after = orders.countByStatusBefore(OrderStatus.UUSI, cutoff);
        log.info("[MASSA] JPQL UPDATE: NEW-tilauksia ennen {} oli {}, päivitettiin {}, jäljellä {}",
                cutoff, before, updated, after);
        return updated;
    }

    // Criteria API UPDATE: vähissä olevien tuotteiden varaston täydennys.
    @Transactional
    public int restockLowStock(Integer supplierId, int threshold, int amount) {
        int updated = products.restockLowStock(supplierId, threshold, amount);
        log.info("[MASSA] CriteriaUpdate: toimittaja={}, saldo < {} -> +{} kpl, päivitettiin {} tuotetta",
                supplierId == null ? "kaikki" : supplierId, threshold, amount, updated);
        return updated;
    }

    // JPQL-raporttihaku: myynti tuoteryhmittäin aikaväliltä, peruttuja tilauksia ei lasketa.
    @Transactional(readOnly = true)
    public List<CategorySales> salesByCategory(LocalDateTime from, LocalDateTime to) {
        List<CategorySales> rows = orderItems.salesByCategory(from, to, OrderStatus.PERUTTU);
        log.info("[MASSA] JPQL GROUP BY: {} - {} -> {} tuoteryhmää", from, to, rows.size());
        return rows;
    }
}
