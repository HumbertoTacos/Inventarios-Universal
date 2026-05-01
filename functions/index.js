const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

exports.generarNombreLower = onDocumentWritten("productos/{productoId}", (event) => {
    // Si el documento fue borrado, no hacemos nada
    if (!event.data.after.exists) {
        return null;
    }

    const data = event.data.after.data();
    const nombre = data.nombre;
    const nombreLowerActual = data.nombreLower;

    // Validamos que exista el nombre
    if (nombre) {
        const nuevoNombreLower = nombre.toLowerCase();

        // CRÍTICO: Prevenir loops infinitos.
        // Solo actualizamos si el nombreLower no existe o no coincide.
        if (nuevoNombreLower !== nombreLowerActual) {
            console.log(`Actualizando nombreLower para: ${nombre}`);
            return event.data.after.ref.update({
                nombreLower: nuevoNombreLower
            });
        }
    }

    return null;
});