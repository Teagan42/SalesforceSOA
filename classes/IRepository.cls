public interface IRepository
{
    /**
     * Retrieve the repository save point for rollback
     **/
    Savepoint getSavepoint();

    /**
     * Rollback changes to the specified save point
     *
     * @param savepoint The savepoint to roll changes back to
     **/
    void rollback(Savepoint savepoint);

    /**
     * Insert records into the repository
     *
     * @param records The set records to be inserted
     **/
    void doInsert(List<SObject> records);

    /**
     * Insert records into the repository
     *
     * @param records The set of records to be inserted
     * @param option The options for the operation
     **/
    List<Repository.Result> doInsert(List<SObject> records, RepositoryOptions option);

    /**
     * Update records in the repository
     *
     * @param records The set of records to be updated
     **/
    void doUpdate(List<SObject> records);

    /**
     * Update records in the repository
     *
     * @param records The set of records to be updated
     * @param option The options for the operation
     **/
    List<Repository.Result> doUpdate(List<SObject> records, RepositoryOptions option);

    /**
     * Delete records from the repository
     *
     * @param records The set of records to be deleted
     **/
    void doDelete(List<SObject> records);

    /**
     * Delete records from the repository
     *
     * @param records The set of records to delete
     * @param option The options for the operation
     **/
    List<Repository.Result> doDelete(List<SObject> records, RepositoryOptions option);
}