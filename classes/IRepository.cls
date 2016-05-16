public interface IRepository
{
    public class Result
    {
        Id entityId;
        String errorMessage;
        Boolean successful;
    }

    public class SavePoint
    {
        // TODO
    }

    public enum Options
    {
        ALL_OR_NOTHING,
        ALLOW_ERRORS
    }

    /**
     * Retrieve the repository save point for rollback
     **/
    void getSavePoint();

    /**
     * Rollback changes to the specified save point
     *
     * @param savepoint The savepoint to roll changes back to
     **/
    void rollback(SavePoint savepoint);

    /**
     * Insert records into the repository
     *
     * @param records The set records to be inserted
     **/
    void doInsert(Set<SObject> records);

    /**
     * Insert records into the repository
     *
     * @param records The set of records to be inserted
     * @param option The options for the operation
     **/
    List<Result> doInsert(Set<SObject> records, Options option);

    /**
     * Update records in the repository
     *
     * @param records The set of records to be updated
     **/
    void doUpdate(Set<SObject> records);

    /**
     * Update records in the repository
     *
     * @param records The set of records to be updated
     * @param option The options for the operation
     **/
    List<Result> doUpdate(Set<SObject> records, Options option);

    /**
     * Delete records from the repository
     *
     * @param records The set of records to be deleted
     **/
    void doDelete(Set<SObject> records);

    /**
     * Delete records from the repository
     *
     * @param records The set of records to delete
     * @param option The options for the operation
     **/
    List<Result> doDelete(Set<SObject> records, Options option);
}