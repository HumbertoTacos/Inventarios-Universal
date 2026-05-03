const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onObjectFinalized } = require("firebase-functions/v2/storage");
const admin = require("firebase-admin");
const csv = require("csv-parser");
const { logger } = require("firebase-functions");

admin.initializeApp();

/**
 * Trigger: Cuando un documento de producto es escrito.
 * Acción: Asegura que nombreLower esté sincronizado para búsquedas.
 */
exports.generarNombreLower = onDocumentWritten("negocios/{negocioId}/productos/{productoId}", (event) => {
    if (!event.data.after.exists) return null;

    const data = event.data.after.data();
    const nombre = data.nombre;
    const nombreLowerActual = data.nombreLower;

    if (nombre) {
        const nuevoNombreLower = nombre.toLowerCase();
        if (nuevoNombreLower !== nombreLowerActual) {
            return event.data.after.ref.update({ nombreLower: nuevoNombreLower });
        }
    }
    return null;
});

/**
 * Trigger: Cuando un archivo CSV se sube a importaciones/{negocioId}/...
 * Acción: Lee el archivo, lo parsea y lo inserta en Firestore por lotes (Batches).
 */
exports.procesarImportacionCSV = onObjectFinalized({
    region: "us-east1",
}, async (event) => {
    const filePath = event.data.name;

    // Solo procesar archivos en la carpeta de importaciones
    if (!filePath.startsWith("importaciones/")) return null;

    const pathParts = filePath.split("/");
    if (pathParts.length < 3) return null;

    const negocioId = pathParts[1];
    const fileName = pathParts[2];

    if (!fileName.endsWith(".csv")) return null;

    logger.log(`Iniciando procesamiento de CSV: ${fileName} para el negocio: ${negocioId}`);

    const bucket = admin.storage().bucket(event.data.bucket);
    const file = bucket.file(filePath);
    const db = admin.firestore();
    const productsRef = db.collection("negocios").doc(negocioId).collection("productos");

    return new Promise((resolve, reject) => {
        const results = [];
        file.createReadStream()
            .pipe(csv())
            .on("data", (data) => results.push(data))
            .on("end", async () => {
                logger.log(`Parseo completado. ${results.length} filas encontradas.`);

                try {
                    // Procesar en lotes de 500 (límite de Firestore)
                    const chunks = [];
                    for (let i = 0; i < results.length; i += 500) {
                        chunks.push(results.slice(i, i + 500));
                    }

                    for (const chunk of chunks) {
                        const batch = db.batch();
                        chunk.forEach((row) => {
                            const newDocRef = productsRef.doc();
                            // Mapeo de columnas CSV -> Modelo Firestore
                            const nombre = (row.Nombre || row.nombre || "").trim();
                            if (!nombre) return;

                            batch.set(newDocRef, {
                                nombre: nombre,
                                nombreLower: nombre.toLowerCase(),
                                categoria: (row.Categoria || row.categoria || "General").trim(),
                                precio: parseFloat(row.Precio || row.precio || "0"),
                                costo_promedio: parseFloat(row.Costo || row.costo || "0"),
                                cantidad: parseFloat(row.Cantidad || row.cantidad || "0"),
                                codigoBarras: (row.CodigoBarras || row.codigoBarras || "").trim() || null,
                                activo: true,
                                esBase: true,
                                fechaCreacion: admin.firestore.FieldValue.serverTimestamp(),
                            });
                        });
                        await batch.commit();
                        logger.log("Batch de 500 registros procesado exitosamente.");
                    }

                    // Opcional: Eliminar el archivo después de procesar
                    // await file.delete();
                    logger.log("Importación finalizada con éxito.");
                    resolve();
                } catch (error) {
                    logger.error("Error al procesar los lotes en Firestore:", error);
                    reject(error);
                }
            })
            .on("error", (error) => {
                logger.error("Error al leer el archivo desde Storage:", error);
                reject(error);
            });
    });
});