#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const outDir = path.join(__dirname, '../../out');
const lockFile = path.join(__dirname, 'events.lock');

function extractEventsFromArtifact(artifactPath) {
    const content = JSON.parse(fs.readFileSync(artifactPath, 'utf8'));
    const events = [];
    
    if (content.abi) {
        for (const item of content.abi) {
            if (item.type === 'event') {
                const params = item.inputs.map(input => input.type).join(',');
                events.push(`${item.name}(${params})`);
            }
        }
    }
    
    return events;
}

function scanOutDirectory(dir) {
    const allEvents = new Set();
    
    if (!fs.existsSync(dir)) {
        console.error('out/ directory not found. Run forge build first.');
        process.exit(1);
    }
    
    function walk(currentPath) {
        const entries = fs.readdirSync(currentPath, { withFileTypes: true });
        
        for (const entry of entries) {
            const fullPath = path.join(currentPath, entry.name);
            
            if (entry.isDirectory()) {
                walk(fullPath);
            } else if (entry.name.endsWith('.json') && !entry.name.includes('.metadata.json')) {
                const events = extractEventsFromArtifact(fullPath);
                events.forEach(e => allEvents.add(e));
            }
        }
    }
    
    walk(dir);
    return Array.from(allEvents).sort();
}

function loadExpectedEvents(lockPath) {
    if (!fs.existsSync(lockPath)) {
        console.error('events.lock not found.');
        process.exit(1);
    }
    
    return fs.readFileSync(lockPath, 'utf8')
        .split('\n')
        .map(line => line.trim())
        .filter(line => line.length > 0)
        .sort();
}

function main() {
    console.log('Extracting events from build artifacts...');
    const foundEvents = scanOutDirectory(outDir);
    
    console.log('Loading expected events from lock file...');
    const expectedEvents = loadExpectedEvents(lockFile);
    
    console.log('\nExpected events:');
    expectedEvents.forEach(e => console.log(`  ${e}`));
    
    console.log('\nFound events:');
    foundEvents.forEach(e => console.log(`  ${e}`));
    
    const missing = expectedEvents.filter(e => !foundEvents.includes(e));
    const extra = foundEvents.filter(e => !expectedEvents.includes(e));
    
    if (missing.length > 0) {
        console.error('\n❌ Missing events:');
        missing.forEach(e => console.error(`  ${e}`));
        process.exit(1);
    }
    
    if (extra.length > 0) {
        console.warn('\n⚠️  Extra events (not in lock file):');
        extra.forEach(e => console.warn(`  ${e}`));
    }
    
    console.log('\n✅ All expected events found!');
}

main();
