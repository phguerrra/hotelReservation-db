import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.SQLException;

public class InsertData {
    public static void main(String[] args) {
        String url = "jdbc:postgresql://localhost:5432/hotel_db"; // ajuste o nome do banco se for diferente
        String user = "postgres";       // seu usuário
        String password = "1234";  // sua senha

        int totalRegistros = 2_000_000; // quantidade exigida
        int batchSize = 10_000;         // insere em blocos

        String sql = "INSERT INTO Customers (full_name, email, phone) VALUES (?, ?, ?)";

        long start = System.currentTimeMillis();

        try (Connection conn = DriverManager.getConnection(url, user, password)) {
            // 🔹 Limpa a tabela antes de inserir para evitar duplicados
            conn.createStatement().executeUpdate("TRUNCATE TABLE Customers RESTART IDENTITY CASCADE");

            conn.setAutoCommit(false); // performance: desliga auto commit

            try (PreparedStatement ps = conn.prepareStatement(sql)) {
                for (int i = 1; i <= totalRegistros; i++) {
                    ps.setString(1, "Cliente " + i);
                    ps.setString(2, "cliente" + i + "@email.com");
                    ps.setString(3, "55" + String.format("%09d", i));
                    ps.addBatch();

                    // executa em lotes de 10.000
                    if (i % batchSize == 0) {
                        ps.executeBatch();
                        conn.commit();
                        System.out.println(i + " registros inseridos...");
                    }
                }

                // executa os registros que sobraram
                ps.executeBatch();
                conn.commit();
            }

            long end = System.currentTimeMillis();
            double tempoSegundos = (end - start) / 1000.0;

            System.out.println("✅ Inserção concluída!");
            System.out.println("⏱ Tempo total: " + tempoSegundos + " segundos.");

        } catch (SQLException e) {
            e.printStackTrace();
        }
    }
}

