package fi.metropolia.webstore.entity;

public enum OrderStatus {
    UUSI("NEW"),
    TOIMITETTU("SHIPPED"),
    PERUTTU("CANCELLED");

    private final String code;

    OrderStatus(String code) {
        this.code = code;
    }

    public String getCode() {
        return code;
    }

    public static OrderStatus fromCode(String code) {
        for (OrderStatus status : values()) {
            if (status.code.equals(code)) {
                return status;
            }
        }
        throw new IllegalArgumentException("Tuntematon tilauksen tila: " + code);
    }
}
