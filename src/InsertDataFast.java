import java.sql.Connection;
import java.sql.DriverManager;
import org.postgresql.copy.CopyManager;
import org.postgresql.core.BaseConnection;
import java.io.StringReader;

public class InsertDataFast {
    public static void main(String[] args) {
        String url = "jdbc:postgresql://localhost:5432/hotel_db";
        String user = "postgres";
        String password = "1234";

        int totalRegistros = 2_000_000;

        long start = System.currentTimeMillis();

        try (Connection conn = DriverManager.getConnection(url, user, password)) {
            // 🔹 Trunca a tabela antes de inserir
            conn.createStatement().executeUpdate("TRUNCATE TABLE Customers RESTART IDENTITY CASCADE");

            CopyManager copyManager = new CopyManager((BaseConnection) conn);

            StringBuilder sb = new StringBuilder();

            for (int i = 1; i <= totalRegistros; i++) {
                sb.append("Cliente " + i)
                        .append("\t") // separador de colunas
                        .append("cliente" + i + "@email.com")
                        .append("\t")
                        .append("55" + String.format("%09d", i))
                        .append("\n"); // nova linha

                // envia em blocos de 50 mil
                if (i % 50_000 == 0) {
                    StringReader reader = new StringReader(sb.toString());
                    copyManager.copyIn("COPY Customers(full_name, email, phone) FROM STDIN WITH DELIMITER E'\\t'", reader);
                    sb.setLength(0); // limpa buffer
                    System.out.println(i + " registros inseridos...");
                }
            }

            // últimos registros
            if (sb.length() > 0) {
                StringReader reader = new StringReader(sb.toString());
                copyManager.copyIn("COPY Customers(full_name, email, phone) FROM STDIN WITH DELIMITER E'\\t'", reader);
            }

            long end = System.currentTimeMillis();
            double tempoSegundos = (end - start) / 1000.0;

            System.out.println("✅ Inserção concluída via COPY!");
            System.out.println("⏱ Tempo total: " + tempoSegundos + " segundos.");

        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
