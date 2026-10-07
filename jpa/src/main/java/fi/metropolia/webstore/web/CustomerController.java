package fi.metropolia.webstore.web;

import fi.metropolia.webstore.dto.Requests.CustomerRequest;
import fi.metropolia.webstore.dto.Responses.CustomerResponse;
import fi.metropolia.webstore.dto.Responses.OrderResponse;
import fi.metropolia.webstore.service.CustomerService;
import fi.metropolia.webstore.service.OrderService;
import jakarta.validation.Valid;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/customers")
public class CustomerController {

    private final CustomerService customers;
    private final OrderService orders;

    public CustomerController(CustomerService customers, OrderService orders) {
        this.customers = customers;
        this.orders = orders;
    }

    @GetMapping
    public Page<CustomerResponse> list(@RequestParam(defaultValue = "0") int page,
                                       @RequestParam(defaultValue = "20") int size) {
        PageRequest pageable = PageRequest.of(page, Math.min(size, 100), Sort.by("id"));
        return customers.list(pageable).map(CustomerResponse::of);
    }

    @GetMapping("/{id}")
    public CustomerResponse get(@PathVariable Integer id) {
        return CustomerResponse.of(customers.get(id));
    }

    @GetMapping("/{id}/orders")
    public List<OrderResponse> orders(@PathVariable Integer id) {
        customers.get(id);
        return orders.latestForCustomer(id).stream().map(OrderResponse::withoutItems).toList();
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public CustomerResponse create(@Valid @RequestBody CustomerRequest request) {
        return CustomerResponse.of(customers.create(request));
    }

    @PutMapping("/{id}")
    public CustomerResponse update(@PathVariable Integer id, @Valid @RequestBody CustomerRequest request) {
        return CustomerResponse.of(customers.update(id, request));
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Integer id) {
        customers.delete(id);
    }
}
