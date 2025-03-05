/**
 * Copyright (c) Microsoft Corporation. All rights reserved.
 * Licensed under the MIT License. See License.txt in the project root for
 * license information.
 */

package com.microsoft.azure.samples.controllers;

import jakarta.enterprise.context.RequestScoped;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import jakarta.persistence.TypedQuery;
import jakarta.transaction.Transactional;

import com.microsoft.azure.samples.entities.*;

import java.util.List;

import static jakarta.transaction.Transactional.TxType.REQUIRED;
import static jakarta.transaction.Transactional.TxType.SUPPORTS;

@Transactional(REQUIRED)
@RequestScoped
public class CountryService {

    @PersistenceContext(unitName = "JPAWorldDatasourcePU")
    EntityManager em;

    @Transactional(SUPPORTS)
    public List<String> findAllContinents() {
        TypedQuery<String> query = em.createNamedQuery("Country.findAllContinent", String.class);
        return query.getResultList();
    }

    @Transactional(SUPPORTS)
    public List<Country> findItemByContinent(String continent) {
        TypedQuery<Country> query = em.createNamedQuery("Country.findByContinent", Country.class);
        query.setParameter("continent", continent);
        return query.getResultList();
    }
}
