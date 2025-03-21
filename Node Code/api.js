const axios = require('axios');
const { neon } = require('@neondatabase/serverless');
const cron = require('node-cron');

const sql = neon('postgresql://neondb_owner:npg_eEpHQvI9wkZ6@ep-snowy-cherry-a5njm8rj-pooler.us-east-2.aws.neon.tech/neondb?sslmode=require');

async function process() {
    try {
        const [vrednosti, shelly] = Promise.all([
            await axios.get("https://api-drzavno-test.scv.si/api/tarifa"),
            await axios.get("http://192.168.0.5/rpc/Switch.getStatus?id=0")
        ]);

        const tarifa = vrednosti.data.tarifa;
        const ura = vrednosti.data.ura;
        const datum = vrednosti.data.datum;
        const watt = shelly.data.apower;

        const cas = 5/60;
        const kWh = (cas * watt) / 1000;
        const cena = kWh * tarifa;

        console.log(ura, datum, tarifa, cas, tarifa, kWh, cena);

        if (watt >= 100) {
            await changeLED(100, 0, 0);
        } else {
            await changeLED(0, 0, 100);
        }

        try {
            await sql("INSERT INTO intervali (datum, ura, tarifa, poraba, cena) VALUES ($1, $2, $3, $4, $5)",
                [datum, ura, tarifa, kWh, cena]
            );
        } catch (error) {
            console.log("Error in database: ", error);
        }
    } catch(error) {
        console.log(error);
    }
}

async function changeLED(red, green, blue){
    const config = {
        leds: {
            colors: {
                'switch:0': {
                    on: {
                        rgb: [red, green, blue],
                        brightness: 100
                    }
                }
            }
        }
    }

    const url = `http://192.168.0.5/rpc/PLUGS_UI.SetConfig?config=${encodeURIComponent(JSON.stringify(config))}`
    await axios.get(url);
}

process();

cron.schedule('*/5 * * * *', async () => {
    console.log("Running scheduled start...");
    await process();
})