package fi.metropolia.webstore.service;

import fi.metropolia.webstore.dto.Requests.CustomerRequest;
import fi.metropolia.webstore.entity.Customer;
import fi.metropolia.webstore.repository.CustomerRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class CustomerService {

    private final CustomerRepository customers;

    public CustomerService(CustomerRepository customers) {
        this.customers = customers;
    }

    @Transactional(readOnly = true)
    public Page<Customer> list(Pageable pageable) {
        return customers.findAll(pageable);
    }

    @Transactional(readOnly = true)
    public Customer get(Integer id) {
        return customers.findById(id).orElseThrow(() -> new NotFoundException("Asiakasta ei löydy: " + id));
    }

    @Transactional
    public Customer create(CustomerRequest r) {
        return customers.saveAndFlush(new Customer(r.firstName(), r.lastName(), r.email(), r.phone()));
    }

    @Transactional
    public Customer update(Integer id, CustomerRequest r) {
        Customer customer = get(id);
        customer.update(r.firstName(), r.lastName(), r.email(), r.phone());
        customers.flush();
        return customer;
    }

    @Transactional
    public void delete(Integer id) {
        customers.delete(get(id));
        customers.flush();
    }
}
