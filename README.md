# setup-cosmosdb-action

This action handles the setup and teardown of a Cosmos DB namespace for running tests.

## Usage

To set up a Cosmos DB account using the Core (SQL) API:

```yaml
      - name: Setup Cosmos DB
        uses: Particular/setup-cosmosdb-action@v1.0.0
        with:
          connection-string-name: EnvVarToCreateWithConnectionString
          azure-credentials: ${{ secrets.AZURE_ACI_CREDENTIALS }}
          tag: PackageName
```

To set up a Cosmos DB account using the Table API:

```yaml
      - name: Setup Cosmos DB
        uses: Particular/setup-cosmosdb-action@v1.0.0
        with:
          api: Table
          connection-string-name: EnvVarToCreateWithConnectionString
          azure-credentials: ${{ secrets.AZURE_ACI_CREDENTIALS }}
          tag: PackageName
```

The setup action also automatically propagates an environment variable called `EnvVarToCreateWithConnectionString_Api` with a value that represens the chosen API flavour.

## Allowed regions

The action tries to create the Cosmos DB account in the same region as the GitHub runner currently assigned to the workflow in order to minimize latency. However, sometimes Azure does not have enough Cosmos DB capacity in certain regions, causing account creation to fail.

The [config branch of this repository](https://github.com/Particular/setup-cosmosdb-action/blob/config/) stores the [azure-regions.config file](https://github.com/Particular/setup-cosmosdb-action/blob/config/azure-regions.config) which controls which regions are allowed. If the GitHub Actions runner is not running in one of these regions, an allowed region will be selected at random.

The list can be updated via a PR to the config branch.

## License

The scripts and documentation in this project are released under the [MIT License](LICENSE).

## Development

Open the folder in Visual Studio Code and do the following:

Log into Azure

```bash
az login
az account set --subscription SUBSCRIPTION_ID
```

Run the npm installation

```bash
npm install
```

When changing `index.js`, either run `npm run dev` beforehand, which will watch the file for changes and automatically compile it, or run `npm run prepare` afterwards.
