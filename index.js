const path = require('path');
const core = require('@actions/core');
const exec = require('@actions/exec');

const setupPs1 = path.resolve(__dirname, '../setup.ps1');
const cleanupPs1 = path.resolve(__dirname, '../cleanup.ps1');

console.log('Setup path: ' + setupPs1);
console.log('Cleanup path: ' + cleanupPs1);

// Only one endpoint, so determine if this is the post action, and set it true so that
// the next time we're executed, it goes to the post action
let isPost = core.getState('IsPost');
core.saveState('IsPost', true);

let connectionStringName = core.getInput('connection-string-name');
let azureCredentials = core.getInput('azure-credentials');
let tagName = core.getInput('tag');
let api = core.getInput('api');

if (api !== 'Sql' && api !== 'Table') {
    core.setFailed("Parameter 'api' must be either 'Sql' or 'Table'. Default is 'Sql'.");
    return;
}

async function run() {

    try {

        if (!isPost) {

            console.log("Running setup action");

            let cosmosName = 'psw-cosmosdb-' + Math.round(10000000000 * Math.random());
            core.saveState('CosmosName', cosmosName);

            console.log("CosmosName = " + cosmosName);

            await exec.exec('pwsh', [
                '-File', setupPs1,
                '-cosmosName', cosmosName,
                '-connectionStringName', connectionStringName,
                '-tagName', tagName,
                '-api', api,
                '-azureCredentials', azureCredentials
            ]);

        } else { // Cleanup

            console.log("Running cleanup");

            let cosmosName = core.getState('CosmosName');

            await exec.exec('pwsh', [
                '-File', cleanupPs1,
                '-cosmosName', cosmosName,
                '-azureCredentials', azureCredentials
            ]);

        }

    } catch (err) {
        core.setFailed(err);
        console.log(err);
    }

}

run();