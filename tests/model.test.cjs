const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const model = vm.createContext({});
vm.runInContext(fs.readFileSync('Model.js', 'utf8').replace('.pragma library', ''), model);

// parseStatus
assert.equal(JSON.stringify(model.parseStatus('{"daemon":{"running":true}}')), JSON.stringify({daemon:{running:true}}));
assert.equal(model.parseStatus('garbage'), null);
assert.equal(JSON.stringify(model.parseStatus('')), JSON.stringify({}));
assert.equal(JSON.stringify(model.parseStatus(null)), JSON.stringify({}));

// parseWakeWords
assert.equal(JSON.stringify(model.parseWakeWords('[{"id":"a","phrase":"hey"}]')), JSON.stringify([{id:'a',phrase:'hey'}]));
assert.equal(JSON.stringify(model.parseWakeWords('[]')), JSON.stringify([]));
assert.equal(JSON.stringify(model.parseWakeWords('garbage')), JSON.stringify([]));
assert.equal(JSON.stringify(model.parseWakeWords('{}')), JSON.stringify([]));

// isDaemonRunning — old format
assert.equal(model.isDaemonRunning({daemon:{running:true}}), true);
assert.equal(model.isDaemonRunning({daemon:{running:false}}), false);
// isDaemonRunning — new IPC format
assert.equal(model.isDaemonRunning({type:'state',state:'armed'}), true);
assert.equal(model.isDaemonRunning({type:'state',state:'paused'}), true);
assert.equal(model.isDaemonRunning({protocol:1,id:'x',type:'state'}), true);
assert.equal(model.isDaemonRunning(null), false);
assert.equal(model.isDaemonRunning({}), false);

// isDaemonPaused — old format
assert.equal(model.isDaemonPaused({daemon:{state:'paused'}}), true);
assert.equal(model.isDaemonPaused({daemon:{state:'running'}}), false);
// isDaemonPaused — new IPC format
assert.equal(model.isDaemonPaused({type:'state',state:'paused'}), true);
assert.equal(model.isDaemonPaused({type:'state',state:'armed'}), false);
assert.equal(model.isDaemonPaused(null), false);

// modelName
assert.equal(model.modelName({model:{name:'moonshine'}}), 'moonshine');
assert.equal(model.modelName({}), '');
assert.equal(model.modelName(null), '');

// backendName
assert.equal(model.backendName({backend:{requested:{runtime:'audiocpp',device:'cpu'}}}), 'audiocpp / cpu');
assert.equal(model.backendName({backend:{kind:'openvino'}}), 'openvino');
assert.equal(model.backendName(null), '');

// parseUnitLoadState
assert.equal(model.parseUnitLoadState('loaded\n'), true);
assert.equal(model.parseUnitLoadState('not-found'), false);
assert.equal(model.parseUnitLoadState(''), false);

console.log('Omawake Model tests passed: status, wake words, daemon state, backend, unit load.');
