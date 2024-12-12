package example;

import org.neo4j.graphdb.Direction;
import org.neo4j.graphdb.Node;
import org.neo4j.procedure.Description;
import org.neo4j.procedure.Name;
import org.neo4j.procedure.Procedure;

import java.util.*;
import java.util.stream.Stream;

public class GetAllRelationships {
    @Procedure(name = "example.getAllRelationships")
    @Description("Get the relationships going in and out of a node.")
    public Stream<Relationships> getAllRelationships(@Name("node") Node node) {
        Set<String> outgoing = new HashSet<>();
        node.getRelationships(Direction.OUTGOING).iterator().forEachRemaining(rel -> outgoing.add(rel.getType().name()));

        Set<String> incoming = new HashSet<>();
        node.getRelationships(Direction.INCOMING).iterator().forEachRemaining(rel -> incoming.add(rel.getType().name()));

        return Stream.of(new Relationships(incoming.stream().toList(), outgoing.stream().toList()));
    }
    public static class Relationships {
        public List<String> outgoing;
        public List<String> incoming;

        public Relationships(List<String> incoming, List<String> outgoing) {
            this.outgoing = outgoing;
            this.incoming = incoming;
        }
    }
}
