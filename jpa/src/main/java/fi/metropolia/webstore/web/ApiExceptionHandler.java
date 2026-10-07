package fi.metropolia.webstore.web;

import fi.metropolia.webstore.service.ConflictException;
import fi.metropolia.webstore.service.NotFoundException;
import org.springframework.dao.DataAccessException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.orm.ObjectOptimisticLockingFailureException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.sql.SQLException;

@RestControllerAdvice
public class ApiExceptionHandler {

    @ExceptionHandler(NotFoundException.class)
    ProblemDetail notFound(NotFoundException e) {
        return ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, e.getMessage());
    }

    @ExceptionHandler(ConflictException.class)
    ProblemDetail conflict(ConflictException e) {
        return ProblemDetail.forStatusAndDetail(HttpStatus.CONFLICT, e.getMessage());
    }

    @ExceptionHandler(ObjectOptimisticLockingFailureException.class)
    ProblemDetail staleVersion(ObjectOptimisticLockingFailureException e) {
        return ProblemDetail.forStatusAndDetail(HttpStatus.CONFLICT, "Tietoa muutettiin samanaikaisesti, hae se uudelleen");
    }

    @ExceptionHandler({IllegalArgumentException.class, MethodArgumentNotValidException.class})
    ProblemDetail badRequest(Exception e) {
        return ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, e.getMessage());
    }

    // Esim. tuotetta tai asiakasta, johon tilaukset viittaavat, ei voi poistaa.
    @ExceptionHandler(DataIntegrityViolationException.class)
    ProblemDetail integrity(DataIntegrityViolationException e) {
        SQLException sql = sqlCause(e);
        if (sql != null && "45000".equals(sql.getSQLState())) {
            return ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, sql.getMessage());
        }
        return ProblemDetail.forStatusAndDetail(HttpStatus.CONFLICT, "Muutos rikkoisi tietokannan eheyden");
    }

    // Tietokannan proseduurien ja liipaisimien SIGNAL SQLSTATE '45000' -virheet ovat sääntörikkeitä.
    @ExceptionHandler(DataAccessException.class)
    ProblemDetail database(DataAccessException e) {
        SQLException sql = sqlCause(e);
        if (sql != null && "45000".equals(sql.getSQLState())) {
            return ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, sql.getMessage());
        }
        throw e;
    }

    private static SQLException sqlCause(Throwable e) {
        for (Throwable t = e; t != null; t = t.getCause()) {
            if (t instanceof SQLException sql) {
                return sql;
            }
        }
        return null;
    }
}
