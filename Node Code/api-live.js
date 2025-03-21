const axios = require('axios');
const express = require('express');

const app = express();

app.get('/refresh', async (req, res) => {
    console.log("Refresh triggered...");

    const shelly = await axios.get("http://192.168.0.5/rpc/Switch.getStatus?id=0");

    const watt = shelly.data.apower;

    res.json(watt);
});

app.listen(3000, '0.0.0.0', async () => {
    console.log("Listening on port 3000.");
});