package fi.metropolia.webstore;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.jdbc.Sql;
import org.springframework.test.web.servlet.MockMvc;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@Sql("/mass-operation-data.sql")
class ApiTest {

    @Autowired
    private MockMvc mvc;

    @Autowired
    private JdbcTemplate jdbc;

    @Test
    void customerCanBeCreatedReadUpdatedAndDeleted() throws Exception {
        String location = mvc.perform(post("/api/customers").contentType(MediaType.APPLICATION_JSON).content("""
                        {"firstName":"Maija","lastName":"Meikäläinen","email":"maija@example.com","phone":"0401234567"}
                        """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").isNumber())
                .andReturn().getResponse().getContentAsString();
        int id = Integer.parseInt(location.replaceAll(".*\"id\":(\\d+).*", "$1"));

        mvc.perform(get("/api/customers/" + id))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.email").value("maija@example.com"));

        mvc.perform(put("/api/customers/" + id).contentType(MediaType.APPLICATION_JSON).content("""
                        {"firstName":"Maija","lastName":"Virtanen","email":"maija@example.com"}
                        """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.lastName").value("Virtanen"));

        mvc.perform(delete("/api/customers/" + id)).andExpect(status().isNoContent());
        mvc.perform(get("/api/customers/" + id)).andExpect(status().isNotFound());
    }

    @Test
    void invalidCustomerIsRejected() throws Exception {
        mvc.perform(post("/api/customers").contentType(MediaType.APPLICATION_JSON).content("""
                        {"firstName":"","lastName":"X","email":"ei-sahkoposti"}
                        """))
                .andExpect(status().isBadRequest());
    }

    @Test
    void customerWithOrdersCannotBeDeleted() throws Exception {
        mvc.perform(delete("/api/customers/1")).andExpect(status().isConflict());
    }

    @Test
    void orderDecreasesStockAndCopiesPrice() throws Exception {
        mvc.perform(post("/api/orders").contentType(MediaType.APPLICATION_JSON).content("""
                        {"customerId":1,"items":[{"productId":106,"quantity":2},{"productId":103,"quantity":5}]}
                        """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("NEW"))
                .andExpect(jsonPath("$.items.length()").value(2))
                .andExpect(jsonPath("$.total").value(547.50));

        assertEquals(28, stock(106));
        assertEquals(45, stock(103));
    }

    // Toisen rivin saldo ei riitä: koko tilaus perutaan, myös ensimmäisen rivin saldon vähennys.
    @Test
    void insufficientStockRollsBackWholeOrder() throws Exception {
        int ordersBefore = jdbc.queryForObject("SELECT COUNT(*) FROM orders", Integer.class);

        mvc.perform(post("/api/orders").contentType(MediaType.APPLICATION_JSON).content("""
                        {"customerId":1,"items":[{"productId":106,"quantity":1},{"productId":104,"quantity":2}]}
                        """))
                .andExpect(status().isConflict());

        assertEquals(30, stock(106));
        assertEquals(1, stock(104));
        assertEquals(ordersBefore, jdbc.queryForObject("SELECT COUNT(*) FROM orders", Integer.class));
    }

    @Test
    void productSearchAndBulkEndpoints() throws Exception {
        mvc.perform(get("/api/products").param("categoryId", "1").param("maxPrice", "20").param("inStock", "true"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[0].categoryName").value("Elektroniikka"));

        mvc.perform(post("/api/admin/orders/cancel-stale").param("before", "2025-01-01"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.affectedRows").value(3));

        mvc.perform(post("/api/admin/products/restock").contentType(MediaType.APPLICATION_JSON).content("""
                        {"threshold":3,"amount":10}
                        """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.affectedRows").value(3));

        mvc.perform(get("/api/reports/sales-by-category").param("from", "2024-01-01").param("to", "2025-01-01"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].categoryName").value("Elektroniikka"));
    }

    @Test
    void orderStatusChangeAndUnknownStatus() throws Exception {
        mvc.perform(put("/api/orders/1004/status").contentType(MediaType.APPLICATION_JSON).content("""
                        {"status":"SHIPPED"}
                        """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("SHIPPED"))
                .andExpect(jsonPath("$.deliveryDate").isNotEmpty());

        mvc.perform(put("/api/orders/1004/status").contentType(MediaType.APPLICATION_JSON).content("""
                        {"status":"LOST"}
                        """))
                .andExpect(status().isBadRequest());
    }

    private int stock(int productId) {
        return jdbc.queryForObject("SELECT stock_quantity FROM products WHERE id = ?", Integer.class, productId);
    }
}
