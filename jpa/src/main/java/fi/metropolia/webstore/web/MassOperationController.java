package fi.metropolia.webstore.web;

import fi.metropolia.webstore.dto.CategorySales;
import fi.metropolia.webstore.dto.Requests.RestockRequest;
import fi.metropolia.webstore.dto.Responses.BulkResult;
import fi.metropolia.webstore.service.MassOperationService;
import jakarta.validation.Valid;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api")
public class MassOperationController {

    private final MassOperationService massOperations;

    public MassOperationController(MassOperationService massOperations) {
        this.massOperations = massOperations;
    }

    @PostMapping("/admin/orders/cancel-stale")
    public BulkResult cancelStaleOrders(@RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate before) {
        return new BulkResult("cancel-stale-orders", massOperations.cancelStaleOrders(before.atStartOfDay()));
    }

    @PostMapping("/admin/products/restock")
    public BulkResult restock(@Valid @RequestBody RestockRequest request) {
        return new BulkResult("restock-low-stock",
                massOperations.restockLowStock(request.supplierId(), request.threshold(), request.amount()));
    }

    // Aikaväli on puoliavoin [from, to).
    @GetMapping("/reports/sales-by-category")
    public List<CategorySales> salesByCategory(@RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
                                               @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        if (!from.isBefore(to)) {
            throw new IllegalArgumentException("from-päivän on oltava ennen to-päivää");
        }
        return massOperations.salesByCategory(from.atStartOfDay(), to.atStartOfDay());
    }
}
