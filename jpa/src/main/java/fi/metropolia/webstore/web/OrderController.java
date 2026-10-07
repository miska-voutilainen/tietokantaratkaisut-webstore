package fi.metropolia.webstore.web;

import fi.metropolia.webstore.dto.Requests.OrderRequest;
import fi.metropolia.webstore.dto.Requests.StatusChangeRequest;
import fi.metropolia.webstore.dto.Responses.OrderResponse;
import fi.metropolia.webstore.dto.Responses.StatusHistoryResponse;
import fi.metropolia.webstore.entity.OrderStatus;
import fi.metropolia.webstore.service.OrderService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;

// Tilauksia ei poisteta (DELETE puuttuu tarkoituksella); peruminen tehdään tilamuutoksella CANCELLED.
@RestController
@RequestMapping("/api/orders")
public class OrderController {

    private final OrderService orders;

    public OrderController(OrderService orders) {
        this.orders = orders;
    }

    @GetMapping("/{id}")
    public OrderResponse get(@PathVariable Integer id) {
        return OrderResponse.of(orders.get(id));
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public OrderResponse create(@Valid @RequestBody OrderRequest request) {
        return OrderResponse.of(orders.create(request));
    }

    @PutMapping("/{id}/status")
    public OrderResponse changeStatus(@PathVariable Integer id, @Valid @RequestBody StatusChangeRequest request) {
        return OrderResponse.withoutItems(orders.changeStatus(id, OrderStatus.fromCode(request.status())));
    }

    @GetMapping("/{id}/status-history")
    public List<StatusHistoryResponse> statusHistory(@PathVariable Integer id) {
        orders.get(id);
        return orders.statusHistory(id).stream().map(StatusHistoryResponse::of).toList();
    }
}
