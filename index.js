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

console.log("Is Post = " + isPost);

let connectionStringName = core.getInput('connection-string-name');
let azureCredentials = core.getInput('azure-credentials');
let azureAllowedRegions = core.getInput('azure-allowed-regions');
let tagName = core.getInput('tag');

console.log('Inputs (except credentials)');

console.log('connection-string-name');
console.log(connectionStringName);
console.log('azure-allowed-regions');
console.log(azureAllowedRegions);
console.log('tag');
console.log(tagName);

async function run() {

    try {

        if (!isPost) {

            console.log("Running setup action");

            let cosmosName = 'psw-cosmosdb-' + Math.round(10000000000 * Math.random());
            core.saveState('CosmosName', cosmosName);

            console.log("Cosmos Name = " + cosmosName);

            await exec.exec('pwsh' [
                '-File', setupPs1,
                '-cosmosName', cosmosName,
                '-connectionStringName', connectionStringName,
                '-azureAllowedRegions', azureAllowedRegions,
                '-tagName', tagName
            ]);

        } else { // Cleanup

            console.log("Running cleanup");

            let cosmosName = core.getState('CosmosName');

            await exec.exec('pwsh' [
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

console.log("Running");
run();